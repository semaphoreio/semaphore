defmodule Block.Blocks.Termination.Test do
  use ExUnit.Case

  alias Block.Blocks.Model.{Blocks, BlocksQueries}
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.BlockSubppls.Model.BlockSubpplsQueries
  alias Block.Tasks.Model.{Tasks, TasksQueries}
  alias Block.EctoRepo, as: Repo
  alias Test.Helpers

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    ppl_id = UUID.uuid4()
    args = %{"service" => "local", "repo_name" => "2_basic"}
    job_1 = %{"name" => "job1", "commands" => ["sleep 1", "echo to do"]}
    job_2 = %{"name" => "job2", "commands" => ["sleep 2", "echo to do"]}
    job_3 = %{"name" => "job3", "commands" => ["sleep 3", "echo to do to do to do to dooo"]}
    jobs_list = [job_1, job_2, job_3]
    ppl_commands = ["cd other_project"]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"agent" => agent, "jobs" => jobs_list,
              "ppl_commands" => ppl_commands}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition = %{"build" => build, "includes" => includes}
    src_args = %{"git_ref_type" => "branch"}
    request = %{ppl_id: ppl_id, pple_block_index: 0, request_args: args, source_args: src_args,
                version: "v3.0", definition: definition, hook_id: UUID.uuid4()}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    {:ok, blk} = BlocksQueries.insert(blk_req)

    {:ok, %{blk: blk}}
  end

  test "stop blk in initializing state", ctx do
    blk = Map.get(ctx, :blk)
    assert blk.state == "initializing"

    t_params = %{request: "stop", desc: "API call"}
    handler = Block.Blocks.STMHandler.InitializingState
    desired_result = {"done", "canceled", "user"}

    assert_terminated(blk, t_params, handler, desired_result, 3_000)
  end

  test "cancel blk in initializing state", ctx do
    blk = Map.get(ctx, :blk)
    assert blk.state == "initializing"

    t_params = %{request: "cancel", desc: "API call"}
    handler = Block.Blocks.STMHandler.InitializingState
    desired_result = {"done", "canceled", "user"}

    assert_terminated(blk, t_params, handler, desired_result, 3_000)
  end

  # When a block is being stopped (e.g. fast-failing of a sibling block)
  # but its task had already finished, the block must keep the task's real verdict
  # instead of being relabelled "stopped" — otherwise a partial rebuild needlessly re-runs
  # an already-passed block.
  test "stopping a block whose task already passed records the block as passed", ctx do
    blk = Map.get(ctx, :blk)

    {:ok, _task} = insert_done_task(blk.block_id, "passed", nil)
    {:ok, blk} = put_in_stopping(blk, "API call")

    {:ok, pid} = Block.Blocks.STMHandler.StoppingState.start_link()
    args = [blk, {"done", "passed", nil}, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 3_000)
  end

  test "stopping a block whose task already failed records the block as failed", ctx do
    blk = Map.get(ctx, :blk)

    {:ok, _task} = insert_done_task(blk.block_id, "failed", "test")
    {:ok, blk} = put_in_stopping(blk, "API call")

    {:ok, pid} = Block.Blocks.STMHandler.StoppingState.start_link()
    args = [blk, {"done", "failed", "test"}, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 3_000)
  end

  test "stopping a block whose task was interrupted records it as stopped", ctx do
    blk = Map.get(ctx, :blk)

    {:ok, _task} = insert_done_task(blk.block_id, "stopped", "user")
    {:ok, blk} = put_in_stopping(blk, "API call")

    {:ok, pid} = Block.Blocks.STMHandler.StoppingState.start_link()
    args = [blk, {"done", "stopped", "user"}, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 3_000)
  end

  # A task terminated before it ran ends up "canceled"; the stopped block must still be
  # recorded "stopped" (only real passed/failed verdicts are preserved), not "canceled".
  test "stopping a block whose task was canceled records it as stopped", ctx do
    blk = Map.get(ctx, :blk)

    {:ok, _task} = insert_done_task(blk.block_id, "canceled", "user")
    {:ok, blk} = put_in_stopping(blk, "API call")

    {:ok, pid} = Block.Blocks.STMHandler.StoppingState.start_link()
    args = [blk, {"done", "stopped", "user"}, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 3_000)
  end

  @tag :integration
  test "stop blk in running state", ctx do
    blk = Map.get(ctx, :blk)
    assert blk.state == "initializing"

    {:ok, pid} = Block.Blocks.STMHandler.InitializingState.start_link()
    args = [blk, {"running", nil, nil}, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 4_000)

    blk = Repo.get(Blocks, blk.id)
    t_params = %{request: "stop", desc: "API call"}
    handler = Block.Blocks.STMHandler.RunningState
    desired_result = {"stopping", nil, nil}

    assert_terminated(blk, t_params, handler, desired_result, 4_000)

    blk = Blocks
           |> Repo.get(blk.id)
           |> assert_task_termination_initiated()
           |> assert_all_subppls_termination_initiated()

    {:ok, pid} = Block.Blocks.STMHandler.StoppingState.start_link()
    {:ok, pid2} = Block.Tasks.STMHandler.PendingState.start_link()
    {:ok, pid3} = Block.Tasks.STMHandler.RunningState.start_link()
    {:ok, pid4} = Block.Tasks.STMHandler.StoppingState.start_link()

    loopers = [pid, pid2, pid3, pid4]
    args = [blk, {"done", "stopped", "user"}, loopers]

    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 4_000)
  end

  defp assert_terminated(blk, t_params, handler, desired_result, timeout) do
    {:ok, blk} = terminate_blk(blk, t_params.request, t_params.desc)

    {:ok, pid} = Kernel.apply(handler, :start_link, [])
    args = [blk, desired_result, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, timeout)
  end

  defp terminate_blk(blk, t_req, t_desc) do
    blk
    |> Blocks.changeset(%{terminate_request: t_req, terminate_request_desc: t_desc})
    |> Repo.update()
  end

  defp insert_done_task(block_id, result, result_reason) do
    params = %{block_id: block_id, state: "done", result: result, result_reason: result_reason,
               in_scheduling: false, build_request_id: UUID.uuid4()}

    %Tasks{} |> Tasks.changeset(params) |> Repo.insert()
  end

  defp put_in_stopping(blk, t_desc) do
    blk
    |> Blocks.changeset(%{state: "stopping", terminate_request: "stop", terminate_request_desc: t_desc})
    |> Repo.update()
  end

  defp assert_task_termination_initiated(blk) do
    assert {:ok, task} = TasksQueries.get_by_id(blk.block_id)
    assert task.terminate_request == blk.terminate_request
    assert task.terminate_request_desc == blk.terminate_request_desc
    blk
  end

  defp assert_all_subppls_termination_initiated(blk) do
    assert {:ok, blk_subppls} = BlockSubpplsQueries.get_all_by_id(blk.block_id)
    blk_subppls |> Enum.each(fn subppl -> assert_subppl_termination_initiated(subppl, blk) end)
    blk
  end

  defp assert_subppl_termination_initiated(subppl, blk) do
    assert subppl.terminate_request == blk.terminate_request
    assert subppl.terminate_request_desc == blk.terminate_request_desc
  end

  def check_state?(blk, desired_state, looper) do
    :timer.sleep 500
    blk = Repo.get(Blocks, blk.id)
    check_state_({blk.state, blk.result, blk.result_reason}, blk, desired_state, looper)
  end

  defp check_state_({state, result, reason}, blk, {desired_state, desired_result, desired_reason}, looper)
  when state == desired_state and result == desired_result and reason == desired_reason do
    Enum.each(looper, fn lp -> GenServer.stop(lp) end)
    assert blk.recovery_count == 0
    :pass
  end
  defp check_state_(_, blk, desired_result, looper), do: check_state?(blk, desired_result, looper)

end
