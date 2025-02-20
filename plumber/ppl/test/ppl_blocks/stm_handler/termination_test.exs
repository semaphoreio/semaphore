defmodule Ppl.PplBlocks.Termination.Test do
  use Ppl.IntegrationCase

  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.PplBlocks.Model.PplBlocks
  alias Ppl.EctoRepo, as: Repo
  alias Test.Helpers

  setup do
    Test.Helpers.truncate_db()

    request_args = Test.Helpers.schedule_request_factory(:local)

    job_1 = %{"name" => "job1", "commands" => ["sleep 1", "echo one"]}
    job_2 = %{"name" => "job2", "commands" => ["sleep 2", "echo two"]}
    job_3 = %{"name" => "job3", "commands" => ["sleep 3", "echo five"]}
    jobs_list = [job_1, job_2, job_3]
    build = %{"jobs" => jobs_list}

    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v3.0", "agent" => agent,
                   "blocks" => [%{"build" => build}]}

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)
    {:ok, _}       = PplsQueries.insert(ppl_req)
    "update pipelines set state = 'running' where ppl_id = '#{ppl_req.id}'"
    |> Repo.query()
    {:ok, ppl_blk} = insert_ppl_blk(ppl_req.id, 0)

    {:ok, %{ppl_blk: ppl_blk}}
  end

  defp insert_ppl_blk(ppl_id, block_index) do
    params = %{ppl_id: ppl_id, block_index: block_index}
      |> Map.put(:state, "waiting")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:name, "blk #{inspect(block_index)}")
      |> Map.put(:exec_time_limit_min, 50)

    %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert
  end

  test "stop ppl-blk in waiting state", ctx do
    ppl_blk = Map.get(ctx, :ppl_blk)
    assert ppl_blk.state == "waiting"

    t_params = %{request: "stop", desc: "API call" }
    handler = Ppl.PplBlocks.STMHandler.WaitingState
    desired_result = {"done", "canceled", "user"}

    assert_terminated(ppl_blk, t_params, handler, desired_result, 3_000)
  end

  test "cancel ppl-blk in waiting state", ctx do
    ppl_blk = Map.get(ctx, :ppl_blk)
    assert ppl_blk.state == "waiting"

    t_params = %{request: "cancel", desc: "API call" }
    handler = Ppl.PplBlocks.STMHandler.WaitingState
    desired_result = {"done", "canceled", "user"}

    assert_terminated(ppl_blk, t_params, handler, desired_result, 3_000)
  end

  @tag :integration
  test "stop ppl-blk in running state", ctx do
    ppl_blk = Map.get(ctx, :ppl_blk)
    assert ppl_blk.state == "waiting"

    {:ok, pid} = Ppl.PplBlocks.STMHandler.WaitingState.start_link()
    args =[ppl_blk, {"running", nil, nil}, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 4_000)

    ppl_blk = Repo.get(PplBlocks, ppl_blk.id)
    t_params = %{request: "stop", desc: "API call" }
    handler = Ppl.PplBlocks.STMHandler.RunningState
    desired_result = {"stopping", nil, nil}

    assert_terminated(ppl_blk, t_params, handler, desired_result, 4_000)

    loopers = start_all_other_loopers()
    ppl_blk = Repo.get(PplBlocks, ppl_blk.id)
    args =[ppl_blk, {"done", "stopped", "user"}, loopers]

    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 4_000)

    assert {:ok, tl} = TimeLimitsQueries.get_by_id_and_index(ppl_blk.ppl_id, 0)
    assert tl.state == "done"
    assert tl.result == "canceled"
    assert tl.result_reason == "user"
  end

  defp start_all_other_loopers() do
    []
    # PplBlocks Loopers
    |> Enum.concat([Ppl.PplBlocks.STMHandler.StoppingState.start_link()])
    # Blocks Loopers
    |> Enum.concat([Block.Blocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.StoppingState.start_link()])
    # Tasks Loopers
    |> Enum.concat([Block.Tasks.STMHandler.PendingState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.StoppingState.start_link()])
    # TimeLimits Looper
    |> Enum.concat([Ppl.TimeLimits.STMHandler.PplBlockTrackingState.start_link()])
    |> Enum.map(fn {:ok, pid} -> pid end)
  end

  defp assert_terminated(ppl_blk, t_params, handler, desired_result, timeout) do
    {:ok, ppl_blk} = terminate_ppl_blk(ppl_blk, t_params.request, t_params.desc)

    {:ok, pid} = Kernel.apply(handler, :start_link, [])
    args =[ppl_blk, desired_result, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, timeout)
  end

  defp terminate_ppl_blk(ppl_blk, t_req, t_desc) do
    ppl_blk
    |> PplBlocks.changeset(%{terminate_request: t_req, terminate_request_desc: t_desc})
    |> Repo.update()
  end

  def check_state?(ppl_blk, desired_state, looper) do
    :timer.sleep 500
    ppl_blk = Repo.get(PplBlocks, ppl_blk.id)
    check_state_({ppl_blk.state, ppl_blk.result, ppl_blk.result_reason}, ppl_blk, desired_state, looper)
  end

  defp check_state_({state, result, reason}, ppl_blk, {desired_state, desired_result, desired_reason}, looper)
  when state == desired_state and result == desired_result and reason == desired_reason do
    Enum.map(looper, fn lp -> GenServer.stop(lp) end)
    assert ppl_blk.recovery_count == 0
    :pass
  end
  defp check_state_(_, ppl_blk, desired_result, looper), do: check_state?(ppl_blk, desired_result, looper)
end
