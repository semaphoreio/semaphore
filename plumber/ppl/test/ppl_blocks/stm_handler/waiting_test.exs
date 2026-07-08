defmodule Ppl.PplBlocks.STMHandler.WaitingState.JobCopyPartition.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Ppl.PplBlocks.Model.PplBlocks
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplBlocks.STMHandler.WaitingState
  alias Ppl.DefinitionReviser
  alias Ppl.Actions

  @partition_key "job_copy_partition"
  @copied_metric "Ppl.job_copy_partition.copied_count"
  @rerun_metric "Ppl.job_copy_partition.rerun_count"
  @mismatch_metric "Ppl.job_copy_partition.mismatch"
  @describe_error_metric "Ppl.job_copy_partition.describe_error"
  @provider_error_metric "Ppl.job_copy_partition.provider_error"

  setup do
    Test.Helpers.truncate_db()

    assert {:ok, %{ppl_id: ppl_id}} =
      %{"requester_id" => ""}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)

    job_1 = %{"name" => "job1", "commands" => ["echo foo"]}
    job_2 = %{"name" => "job2", "commands" => ["echo bar"]}
    job_3 = %{"name" => "job3", "commands" => ["echo baz"]}
    task = %{"jobs" => [job_1, job_2, job_3]}
    agent = %{"machine" => %{"type" => "foo", "os_image" => "bar"}}
    definition = %{"version" => "v1.0", "agent" => agent, "name" => "Test Pipeline",
      "blocks" => [%{"name" => "blk 0", "task" => task}]}

    {:ok, definition} = DefinitionReviser.revise_definition(definition, ppl_req)
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    assert {:ok, %{ppl_id: orig_ppl_id}} =
      %{"requester_id" => ""}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    orig_block_id = UUID.uuid4()

    assert {:ok, _orig_ppl_blk} =
      insert_ppl_blk(orig_ppl_id, 0,
        %{state: "done", result: "failed", result_reason: "test", block_id: orig_block_id})

    assert {:ok, _} =
      "update pipelines set partial_rebuild_of = '#{orig_ppl_id}' where ppl_id = '#{ppl_id}'"
      |> Repo.query()

    org_id = ppl_req.request_args["organization_id"]

    {:ok, %{ppl_id: ppl_id, ppl_req: ppl_req, orig_ppl_id: orig_ppl_id,
            orig_block_id: orig_block_id, org_id: org_id}}
  end

  test "flag ON: passed job is marked for copy, failed jobs run, partition persisted with original_block_id", ctx do
    {a_id, b_id, c_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

    jobs = [
      describe_job(a_id, 0, "FINISHED", "PASSED"),
      describe_job(b_id, 1, "FINISHED", "FAILED"),
      describe_job(c_id, 2, "FINISHED", "FAILED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_called Ppl.Features.job_level_partial_rerun_enabled?(ctx.org_id)
      assert_received {:block_schedule_request, req}

      assert req.request_args[@partition_key] ==
        %{"original_block_id" => ctx.orig_block_id, "jobs" => %{"0" => a_id}}
    end
  end

  test "flag ON: full D-11 predicate - PASSED copies, FAILED and STOPPED run", ctx do
    {a_id, b_id, c_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

    jobs = [
      describe_job(a_id, 0, "FINISHED", "PASSED"),
      describe_job(b_id, 1, "FINISHED", "FAILED"),
      describe_job(c_id, 2, "FINISHED", "STOPPED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      assert req.request_args[@partition_key]["jobs"] == %{"0" => a_id}
    end
  end

  test "fail-closed: lowercase result or non-FINISHED status routes to run, never copy", ctx do
    {a_id, b_id, c_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

    jobs = [
      describe_job(a_id, 0, "FINISHED", "passed"),
      describe_job(b_id, 1, "RUNNING", "PASSED"),
      describe_job(c_id, 2, "FINISHED", "PASSED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      assert req.request_args[@partition_key]["jobs"] == %{"2" => c_id}
    end
  end

  test "fail-closed: missing or unknown result value routes to run, never copy", ctx do
    {a_id, b_id, c_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

    jobs = [
      describe_job(a_id, 0, "FINISHED", "PASSED") |> Map.drop([:result]),
      describe_job(b_id, 1, "FINISHED", "BANANA"),
      describe_job(c_id, 2, "FINISHED", "PASSED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      assert req.request_args[@partition_key]["jobs"] == %{"2" => c_id}
    end
  end

  test "flag OFF: whole block reschedules, no partition key, no describe", ctx do
    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> false end]},
      {Block, [], block_mocks(ctx, [], self())}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      refute Map.has_key?(req.request_args, @partition_key)
      assert_not_called Block.describe(:_)
    end
  end

  test "non-rebuild block: no flag check, no describe, no partition", ctx do
    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: false})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, [], self())}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      refute Map.has_key?(req.request_args, @partition_key)
      assert_not_called Ppl.Features.job_level_partial_rerun_enabled?(:_)
      assert_not_called Block.describe(:_)
    end
  end

  test "partition matches jobs by original index, not list position", ctx do
    {a_id, b_id, c_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

    jobs = [
      describe_job(b_id, 1, "FINISHED", "PASSED"),
      describe_job(c_id, 2, "FINISHED", "PASSED"),
      describe_job(a_id, 0, "FINISHED", "FAILED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      assert req.request_args[@partition_key]["jobs"] == %{"1" => b_id, "2" => c_id}
    end
  end

  test "D-05 passthrough: a passed original that is itself a copy still emits its own job_id", ctx do
    {a_id, b_id, c_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}
    older_id = UUID.uuid4()

    jobs = [
      describe_job(a_id, 0, "FINISHED", "PASSED", %{original_job_id: older_id}),
      describe_job(b_id, 1, "FINISHED", "FAILED"),
      describe_job(c_id, 2, "FINISHED", "FAILED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      assert req.request_args[@partition_key]["jobs"] == %{"0" => a_id}
    end
  end

  test "degrade on job count mismatch: no partition, mismatch metric, block still schedules", ctx do
    {a_id, b_id} = {UUID.uuid4(), UUID.uuid4()}

    jobs = [
      describe_job(a_id, 0, "FINISHED", "PASSED"),
      describe_job(b_id, 1, "FINISHED", "FAILED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())},
      {Watchman, [:passthrough], [increment: fn _ -> :ok end, submit: fn _, _ -> :ok end]}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      refute Map.has_key?(req.request_args, @partition_key)
      assert_called Watchman.increment(@mismatch_metric)
    end
  end

  test "degrade on index mismatch: no partition, mismatch metric, block still schedules", ctx do
    {a_id, b_id, c_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

    jobs = [
      describe_job(a_id, 0, "FINISHED", "PASSED"),
      describe_job(b_id, 1, "FINISHED", "FAILED"),
      describe_job(c_id, 3, "FINISHED", "FAILED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())},
      {Watchman, [:passthrough], [increment: fn _ -> :ok end, submit: fn _, _ -> :ok end]}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      refute Map.has_key?(req.request_args, @partition_key)
      assert_called Watchman.increment(@mismatch_metric)
    end
  end

  test "degrade on describe error: no partition, describe_error metric, block still schedules", ctx do
    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    test_pid = self()

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [],
       [describe: fn _ -> {:error, "grpc error"} end,
        schedule: fn block_request ->
          send(test_pid, {:block_schedule_request, block_request})
          {:ok, UUID.uuid4()}
        end,
        status: fn _ -> %{inserted_at: DateTime.utc_now()} end]},
      {Watchman, [:passthrough], [increment: fn _ -> :ok end, submit: fn _, _ -> :ok end]}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      refute Map.has_key?(req.request_args, @partition_key)
      assert_called Watchman.increment(@describe_error_metric)
    end
  end

  test "degrade on feature provider error: no partition, provider_error metric, block still schedules", ctx do
    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> raise "provider down" end]},
      {Block, [], block_mocks(ctx, [], self())},
      {Watchman, [:passthrough], [increment: fn _ -> :ok end, submit: fn _, _ -> :ok end]}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      refute Map.has_key?(req.request_args, @partition_key)
      assert_called Watchman.increment(@provider_error_metric)
      assert_not_called Block.describe(:_)
    end
  end

  test "degrade on unexpected raise mid-partition: no partition, mismatch metric, block still schedules", ctx do
    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    test_pid = self()

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [],
       [describe: fn _ -> raise "unexpected crash" end,
        schedule: fn block_request ->
          send(test_pid, {:block_schedule_request, block_request})
          {:ok, UUID.uuid4()}
        end,
        status: fn _ -> %{inserted_at: DateTime.utc_now()} end]},
      {Watchman, [:passthrough], [increment: fn _ -> :ok end, submit: fn _, _ -> :ok end]}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, req}
      refute Map.has_key?(req.request_args, @partition_key)
      assert_called Watchman.increment(@mismatch_metric)
    end
  end

  test "partition metrics: copied and rerun counts are emitted", ctx do
    {a_id, b_id, c_id} = {UUID.uuid4(), UUID.uuid4(), UUID.uuid4()}

    jobs = [
      describe_job(a_id, 0, "FINISHED", "PASSED"),
      describe_job(b_id, 1, "FINISHED", "FAILED"),
      describe_job(c_id, 2, "FINISHED", "FAILED")
    ]

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0, %{duplicate: true})

    with_mocks([
      {Ppl.Features, [], [job_level_partial_rerun_enabled?: fn _ -> true end]},
      {Block, [], block_mocks(ctx, jobs, self())},
      {Watchman, [:passthrough], [increment: fn _ -> :ok end, submit: fn _, _ -> :ok end]}
    ]) do
      assert {:ok, %{state: "running", block_id: _}} = run_scheduling(ppl_blk)

      assert_received {:block_schedule_request, _req}
      assert_called Watchman.submit(@copied_metric, 1)
      assert_called Watchman.submit(@rerun_metric, 2)
    end
  end

  defp run_scheduling(ppl_blk) do
    assert {:ok, result_func} = WaitingState.scheduling_handler(ppl_blk)
    assert is_function(result_func)
    result_func.(:repo, :changes)
  end

  defp describe_job(job_id, index, status, result, extra \\ %{}) do
    %{job_id: job_id, index: index, name: "job#{index + 1}", status: status, result: result}
    |> Map.merge(extra)
  end

  defp block_mocks(ctx, jobs, test_pid) do
    [
      describe: fn block_id ->
        assert block_id == ctx.orig_block_id
        {:ok, %{block_id: block_id, build_req_id: UUID.uuid4(),
                jobs: jobs, error_description: ""}}
      end,
      schedule: fn block_request ->
        send(test_pid, {:block_schedule_request, block_request})
        {:ok, UUID.uuid4()}
      end,
      status: fn _ -> %{inserted_at: DateTime.utc_now()} end
    ]
  end

  defp insert_ppl_blk(ppl_id, block_index, extra) do
    params =
      %{ppl_id: ppl_id, block_index: block_index}
      |> Map.put(:state, "waiting")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:name, "blk #{inspect(block_index)}")
      |> Map.merge(extra)

    %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert()
  end
end
