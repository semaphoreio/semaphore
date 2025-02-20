defmodule Block.Looper.Blocks.StateTransition.Test do
  use ExUnit.Case

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Blocks.Model.{Blocks, BlocksQueries}
  alias Block.EctoRepo, as: Repo
  alias Test.Helpers

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    ppl_id = UUID.uuid4()
    args = %{"service" => "local", "repo_name" => "5_v1_full", "ppl_priority" => 50, working_dir: ".semaphore"}
    src_args = %{"git_ref_type" => "branch"}
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands_file" => "job3.sh"}
    jobs_list = [job_1, job_2]
    ppl_commands = ["cd other_project"]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"agent" => agent, "jobs" => jobs_list,
              "ppl_commands" => ppl_commands}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition = %{"build" => build, "includes" => includes}
    request = %{ppl_id: ppl_id, pple_block_index: 0, request_args: args, source_args: src_args,
                version: "v3.0", definition: definition, hook_id: UUID.uuid4()}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    id = blk_req.id

    {:ok, %{block_id: id, blk_req: blk_req}}
  end

  @tag :integration
  test "Blocks looper transitions", ctx do
    {:ok, blk} = BlocksQueries.insert(ctx.blk_req)
    assert blk.state == "initializing"

    {:ok, pid} = Block.Blocks.STMHandler.InitializingState.start_link()
    args = [blk, "running", [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 10_000)

    {:ok, pid} = Block.Blocks.STMHandler.RunningState.start_link()
    {:ok, pid2} = Block.Tasks.STMHandler.PendingState.start_link()
    {:ok, pid3} = Block.Tasks.STMHandler.RunningState.start_link()
    args = [blk, "done", [pid, pid2, pid3]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 10_000)
  end

  @tag :integration
  test "Blocks recovery counter is reset on transition out of scheduling", ctx do
    assert {:ok, blk} = BlocksQueries.insert(ctx.blk_req)
    assert blk.state == "initializing"
    assert {:ok, blk} = blk
      |> Blocks.changeset(%{recovery_count: 1})
      |> Repo.update
    assert blk.recovery_count == 1

    {:ok, pid} = Block.Blocks.STMHandler.InitializingState.start_link()
    args = [blk, "running", [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 10_000)
  end

  @tag :integration
  test "Calls block_done_notification_callback on transition to done", ctx do
    {:ok, blk} = BlocksQueries.insert(ctx.blk_req)
    assert blk.state == "initializing"

    old_callback = set_done_calback(self())

    {:ok, pid} = Block.Blocks.STMHandler.InitializingState.start_link()
    {:ok, pid1} = Block.Blocks.STMHandler.RunningState.start_link()
    {:ok, pid2} = Block.Tasks.STMHandler.PendingState.start_link()
    {:ok, pid3} = Block.Tasks.STMHandler.RunningState.start_link()
    args = [blk, "done", [pid, pid1, pid2, pid3]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 10_000)

    reset_done_calback(old_callback)

    assert_received(:block_done, "block_done_notification_callback not called!")
  end

  def check_state?(blk, desired_state, loopers) do
    :timer.sleep 500
    blk = Repo.get(Blocks, blk.id)
    check_state_(blk.state, blk, desired_state, loopers)
  end

  defp check_state_(state, blk, desired_state, loopers) when state == desired_state do
    Enum.each(loopers, fn(manager) -> GenServer.stop(manager) end)
    assert blk.recovery_count == 0
    :pass
  end
  defp check_state_(_, blk, desired_state, loopers), do: check_state?(blk, desired_state, loopers)

  defp set_done_calback(dest_pid) do
    Application.put_env(:block, :state_transition__test_done_cb, dest_pid)

    old_callback = Application.get_env(:block, :block_done_notification_callback)
    Application.put_env(:block, :block_done_notification_callback,
      {__MODULE__, :send_notification_callback})

    old_callback
  end

  def send_notification_callback(_) do
    Application.get_env(:block, :state_transition__test_done_cb)
    |> send(:block_done)
  end

  defp reset_done_calback(old_callback) do
    Application.put_env(:block, :block_done_notification_callback, old_callback)
  end
end
