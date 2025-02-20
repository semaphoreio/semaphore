defmodule Ppl.Looper.PplBlocks.StateTransition.Test do
  use Ppl.IntegrationCase

  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries, PplBlockConnections}
  alias Ppl.DefinitionReviser
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Actions
  alias Test.Helpers

  setup do
    Test.Helpers.truncate_db()

    assert {:ok, %{ppl_id: ppl_id}} =
      Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    task = %{"jobs" => [job_1, job_2]}

    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition_v1 = %{"version" => "v1.0", "agent" => agent,
                      "blocks" => [%{"task" => task}, %{"task" => task}]}

    id = ppl_req.id

    source_args = %{"git_ref_type" => "branch"}

    {:ok, definition_v1} = DefinitionReviser.revise_definition(definition_v1, ppl_req)
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition_v1)
    {:ok, ppl_req} = PplRequestsQueries.insert_source(ppl_req, source_args)
    "update pipelines set state = 'running', priority = 50 where ppl_id = '#{id}'"
    |> Repo.query()
    PplTracesQueries.set_timestamp(id, :running_at)

    {:ok, %{ppl_id: id, ppl_req: ppl_req}}
  end

  @tag :integration
  test "PplBlocks looper transitions", ctx do
    ppl_id = Map.get(ctx, :ppl_id)

    assert {:ok, ppl_blk0} = insert_ppl_blk(ppl_id, 0)
    assert {:ok, ppl_blk1} = insert_ppl_blk(ppl_id, 1, ppl_blk0.id)

    assert ppl_blk0.state == "waiting"
    assert ppl_blk1.state == "waiting"

    loopers = start_loopers()

    {:ok, pid} = Ppl.PplBlocks.STMHandler.WaitingState.start_link()
    args =[ppl_blk0, "running", pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    assert_ppl_blks_statuses(ppl_id, {"running", nil}, {"waiting", nil})

    {:ok, pid} = Ppl.PplBlocks.STMHandler.RunningState.start_link()
    args =[ppl_blk0, "done", pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    assert_ppl_blks_statuses(ppl_id, {"done", "passed"}, {"waiting", nil})

    {:ok, pid} = Ppl.PplBlocks.STMHandler.WaitingState.start_link()
    args =[ppl_blk1, "running", pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    assert_ppl_blks_statuses(ppl_id, {"done", "passed"}, {"running", nil})

    {:ok, pid} = Ppl.PplBlocks.STMHandler.RunningState.start_link()
    args =[ppl_blk1, "done", pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    assert_ppl_blks_statuses(ppl_id, {"done", "passed"}, {"done", "passed"})

    stop_loopers(loopers)
  end

  @tag :integration
  test "PplBlocks recovery counter is reset on transition out of scheduling", ctx do
    ppl_id = Map.get(ctx, :ppl_id)
    assert {:ok, ppl_blk} = insert_ppl_blk(ppl_id, 0)
    assert ppl_blk.state == "waiting"
    assert {:ok, ppl_blk} = ppl_blk
      |> PplBlocks.changeset(%{recovery_count: 1})
      |> Repo.update
    assert ppl_blk.recovery_count == 1

    loopers = start_loopers()

    {:ok, pid} = Ppl.PplBlocks.STMHandler.WaitingState.start_link()
    args =[ppl_blk, "running", pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 3_000)

    stop_loopers(loopers)
  end

  defp insert_ppl_blk(ppl_id, block_index, dependency \\ nil) do
    params = %{ppl_id: ppl_id, block_index: block_index}
      |> Map.put(:state, "waiting")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:name, "Blk #{inspect(block_index)}")

    {:ok, ppl_blk} = %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert

    assert {:ok, _block_conection} = insert_dependecy(ppl_blk.id, dependency)
    {:ok, ppl_blk}
  end

  defp insert_dependecy(_target, nil), do: {:ok, :pass}
  defp insert_dependecy(target, dependency) do
    params = %{target: target, dependency: dependency}

    %PplBlockConnections{} |> PplBlockConnections.changeset(params) |> Repo.insert
  end

  defp assert_ppl_blks_statuses(ppl_id, status_1, status_2) do
    {state_1, result_1} = status_1
    {state_2, result_2} = status_2

    assert {:ok, ppl_blk1} = PplBlocksQueries.get_by_id_and_index(ppl_id, 0)
    assert {:ok, ppl_blk2} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)

    assert ppl_blk1.state == state_1
    assert ppl_blk1.result == result_1
    assert ppl_blk2.state == state_2
    assert ppl_blk2.result == result_2
  end

  defp start_loopers() do
    []
    # Blocks Loopers
    |> Enum.concat([Block.Blocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.RunningState.start_link()])
    # Tasks Loopers
    |> Enum.concat([Block.Tasks.STMHandler.PendingState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.RunningState.start_link()])
  end

  defp stop_loopers(loopers) do
    loopers |> Enum.map(fn({_resp, pid}) -> GenServer.stop(pid) end)
  end

  def check_state?(ppl_blk, desired_state, looper) do
    :timer.sleep 500
    ppl_blk = Repo.get(PplBlocks, ppl_blk.id)
    check_state_(ppl_blk.state, ppl_blk, desired_state, looper)
  end

  defp check_state_(state, ppl_blk, desired_state, looper) when state == desired_state do
    GenServer.stop(looper)
    assert ppl_blk.recovery_count == 0
    :pass
  end
  defp check_state_(_, ppl_blk, desired_state, looper), do: check_state?(ppl_blk, desired_state, looper)
end
