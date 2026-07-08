defmodule Block.Tasks.STMHandler.PendingState.PartitionFallback.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.Model.Tasks
  alias Block.Tasks.STMHandler.PendingState
  alias Block.EctoRepo, as: Repo
  alias InternalApi.Task.{TaskService, ScheduleResponse}
  alias Util.Proto

  @partition_key "job_copy_partition"
  @rejected_metric "Block.job_copy_partition.rejected_by_task_api"

  setup do
    assert {:ok, _} =
      Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    job = %{"name" => "job1", "commands" => ["echo foo"]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    task_def = %{"jobs" => [job], "agent" => agent}

    {:ok, orig_blk_req} = insert_block_request(%{"service" => "local"}, task_def)
    zebra_task_id = UUID.uuid4()
    assert {:ok, _} = insert_task_row(orig_blk_req.id, "done", %{task_id: zebra_task_id})

    partition = %{"original_block_id" => orig_blk_req.id, "jobs" => %{"0" => UUID.uuid4()}}
    request_args = %{"service" => "local", @partition_key => partition}

    {:ok, blk_req} = insert_block_request(request_args, task_def)
    {:ok, _} = BlockRequestsQueries.insert_build(blk_req, %{build: task_def})

    assert {:ok, pending_task} =
      insert_task_row(blk_req.id, "pending", %{build_request_id: UUID.uuid4()})

    {:ok, %{task_def: task_def, pending_task: pending_task, zebra_task_id: zebra_task_id}}
  end

  test "invalid_argument on a partition-carrying request strips the partition and reschedules whole block", ctx do
    test_pid = self()

    with_mocks([
      {GRPC.Stub, [:passthrough], [connect: fn _ -> {:ok, :fake_channel} end]},
      {TaskService.Stub, [],
       [schedule: fn _channel, request, _opts ->
          send(test_pid, {:schedule_request, request})

          if request.original_task_id != "" do
            {:error, %GRPC.RPCError{status: 3, message: "invalid original_task_id"}}
          else
            %{task: %{id: UUID.uuid4(), created_at: %{seconds: 123_455, nanos: 0}}}
            |> Proto.deep_new(ScheduleResponse)
          end
        end]},
      {Watchman, [:passthrough],
       [increment: fn _ -> :ok end,
        submit: fn _, _ -> :ok end,
        submit: fn _, _, _ -> :ok end]}
    ]) do
      assert {:ok, result_func} = PendingState.scheduling_handler(ctx.pending_task)
      assert {:ok, %{state: "running", task_id: _}} = result_func.(:repo, :changes)

      assert_received {:schedule_request, first}
      assert first.original_task_id == ctx.zebra_task_id

      assert_received {:schedule_request, second}
      assert second.original_task_id == ""
      assert Enum.all?(second.jobs, fn job -> job.original_job_id == "" end)

      assert_called Watchman.increment(@rejected_metric)
    end
  end

  test "invalid_argument on a partition-free request is not retried", ctx do
    {:ok, blk_req} = insert_block_request(%{"service" => "local"}, ctx.task_def)
    {:ok, _} = BlockRequestsQueries.insert_build(blk_req, %{build: ctx.task_def})

    assert {:ok, pending_task} =
      insert_task_row(blk_req.id, "pending", %{build_request_id: UUID.uuid4()})

    test_pid = self()

    with_mocks([
      {GRPC.Stub, [:passthrough], [connect: fn _ -> {:ok, :fake_channel} end]},
      {TaskService.Stub, [],
       [schedule: fn _channel, request, _opts ->
          send(test_pid, {:schedule_request, request})
          {:error, %GRPC.RPCError{status: 3, message: "bad request"}}
        end]},
      {Watchman, [:passthrough],
       [increment: fn _ -> :ok end,
        submit: fn _, _ -> :ok end,
        submit: fn _, _, _ -> :ok end]}
    ]) do
      assert {:ok, result_func} = PendingState.scheduling_handler(pending_task)
      assert {:error, %{description: _}} = result_func.(:repo, :changes)

      assert_received {:schedule_request, _request}
      refute_received {:schedule_request, _}

      assert_not_called Watchman.increment(@rejected_metric)
    end
  end

  defp insert_block_request(request_args, task_def) do
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: request_args,
                source_args: %{"git_ref_type" => "branch"}, version: "v1.0",
                definition: %{"build" => task_def}, hook_id: UUID.uuid4()}

    BlockRequestsQueries.insert_request(request)
  end

  defp insert_task_row(block_id, state, extra) do
    params =
      %{block_id: block_id, state: state, in_scheduling: false}
      |> Map.merge(extra)

    %Tasks{} |> Tasks.changeset(params) |> Repo.insert()
  end
end
