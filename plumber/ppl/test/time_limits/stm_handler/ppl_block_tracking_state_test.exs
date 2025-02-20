defmodule Ppl.TimeLimits.STMHandler.PplBlockTrackingState.Test do
  use Ppl.IntegrationCase, async: false

  import Ecto.Query

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries}
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.DefinitionReviser
  alias Ppl.EctoRepo, as: Repo
  alias Test.Helpers
  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()

    assert {:ok, %{ppl_id: ppl_id}} =
      Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)

    job_1 = %{"name" => "job1", "commands" => ["sleep 1", "echo one"]}
    job_2 = %{"name" => "job2", "commands" => ["sleep 2", "echo two"]}
    job_3 = %{"name" => "job3", "commands" => ["sleep 3", "echo five"]}
    jobs_list = [job_1, job_2, job_3]
    task = %{"jobs" => jobs_list}

    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v1.0", "agent" => agent,
                   "blocks" => [%{"task" => task}]}

    source_args = %{"git_ref_type" => "branch"}


    {:ok, ppl_req} = PplRequestsQueries.insert_source(ppl_req, source_args)
    {:ok, definition} = DefinitionReviser.revise_definition(definition, ppl_req)
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)
    "update pipelines set state = 'running', priority = 50 where ppl_id = '#{ppl_req.id}'"
    |> Repo.query()
    PplTracesQueries.set_timestamp(ppl_req.id, :running_at)
    {:ok, ppl_blk} = insert_ppl_blk(ppl_req.id, 0)

    {:ok, %{ppl_blk: ppl_blk}}
  end

  defp insert_ppl_blk(ppl_id, block_index) do
    params = %{ppl_id: ppl_id, block_index: block_index}
      |> Map.put(:state, "initializing")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:name, "blk #{inspect(block_index)}")
      |> Map.put(:exec_time_limit_min, 50)

    %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert
  end

  @tag :integration
  test "time limit for ppl block goes to done-canceled if block was already finished", ctx do
    blk = Map.get(ctx, :ppl_blk)

    loopers = start_init_loopers() |> start_all_other_loopers()

    args =[blk, {"done", "passed", nil}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 8_000)

    assert {:ok, blk} = PplBlocksQueries.get_by_id_and_index(blk.ppl_id, blk.block_index)
    blk = blk |> Map.put(:exec_time_limit_min, -2)
    assert {:ok, _tl} = TimeLimitsQueries.set_time_limit(blk, "ppl_block")

    {:ok, pid} = Ppl.TimeLimits.STMHandler.PplBlockTrackingState.start_link()

    :timer.sleep(1_500)

    assert {:ok, tl} = TimeLimitsQueries.get_by_id_and_index(blk.ppl_id, blk.block_index)
    assert tl.state == "done"
    assert tl.result == "canceled"
    assert tl.result_reason == "ppl_block done"

    GenServer.stop(pid)
  end

  @tag :integration
  test "pipeline's block is terminated when it is running for longer than execution_time_limt", ctx do
    blk = Map.get(ctx, :ppl_blk)

    loopers = start_init_loopers()

    args =[blk, {"running", nil, nil}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    assert {1,  _} =
      PplBlocks
      |> where([pb], pb.ppl_id == ^blk.ppl_id)
      |> where([pb], pb.block_index == ^blk.block_index)
      |> update(set: [exec_time_limit_min: -2])
      |> Repo.update_all([])

    assert {:ok, blk} = PplBlocksQueries.get_by_id_and_index(blk.ppl_id, blk.block_index)
    assert {:ok, _tl} = TimeLimitsQueries.set_time_limit(blk, "ppl_block")


    loopers = start_all_other_loopers()

    args =[blk, {"done", "stopped", "timeout"}, loopers]

    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 7_000)
  end

  defp start_init_loopers() do
    []
    # PplBlocks Loopers
    |> Enum.concat([Ppl.PplBlocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.WaitingState.start_link()])
  end

  defp start_all_other_loopers(loopers \\ []) do
    loopers
    # PplBlocks Loopers
    |> Enum.concat([Ppl.PplBlocks.STMHandler.RunningState.start_link()])
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
  end

  def check_state?(ppl_blk, desired_state, loopers) do
    :timer.sleep 500
    ppl_blk = Repo.get(PplBlocks, ppl_blk.id)
    check_state_({ppl_blk.state, ppl_blk.result, ppl_blk.result_reason}, ppl_blk, desired_state, loopers)
  end

  defp check_state_({state, result, reason}, ppl_blk, {desired_state, desired_result, desired_reason}, loopers)
  when state == desired_state and result == desired_result and reason == desired_reason do
    Enum.map(loopers, fn {:ok, lp} -> GenServer.stop(lp) end)
    assert ppl_blk.recovery_count == 0
    :pass
  end
  defp check_state_(_, ppl_blk, desired_result, loopers), do: check_state?(ppl_blk, desired_result, loopers)
end
