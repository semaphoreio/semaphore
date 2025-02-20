defmodule Ppl.E2E.ParallelRuns.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions
  alias Ppl.PplTraces.Model.PplTracesQueries

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "when parallel queue processing is set up pipelines from same queue are run in parallel" do
    ppl_id_1 = run_pipeline(:serialized)
    ppl_id_2 = run_pipeline(:parallel)
    ppl_id_3 = run_pipeline(:serialized)
    ppl_id_4 = run_pipeline(:parallel)

    loopers = start_running_loopers()

    assert {:ok, _ppl_1} = Test.Helpers.wait_for_ppl_state(ppl_id_1, "running", 2_000)
    assert {:ok, _ppl_2} = Test.Helpers.wait_for_ppl_state(ppl_id_2, "running", 2_000)
    assert {:ok, _ppl_3} = Test.Helpers.wait_for_ppl_state(ppl_id_3, "queuing", 2_000)
    assert {:ok, _ppl_4} = Test.Helpers.wait_for_ppl_state(ppl_id_4, "running", 2_000)

    loopers = loopers ++ [Ppl.Ppls.STMHandler.RunningState.start_link()]

    assert {:ok, _ppl_3} = Test.Helpers.wait_for_ppl_state(ppl_id_3, "done", 15_000)

    assert {:ok, ptr_1} = PplTracesQueries.get_by_id(ppl_id_1)
    assert {:ok, ptr_2} = PplTracesQueries.get_by_id(ppl_id_2)
    assert {:ok, ptr_3} = PplTracesQueries.get_by_id(ppl_id_3)
    assert {:ok, ptr_4} = PplTracesQueries.get_by_id(ppl_id_4)

    assert :lt == DateTime.compare(ptr_1.done_at, ptr_3.running_at)
    assert :lt == DateTime.compare(ptr_2.done_at, ptr_3.running_at)
    assert :lt == DateTime.compare(ptr_4.done_at, ptr_3.done_at)

    Test.Helpers.stop_all_loopers(loopers)
  end


  defp run_pipeline(mode) do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "29_parallel_runs", "project_id" => "123", "organization_id" => "456"}
      |> set_up_branch(mode)
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    ppl_id
  end

  defp set_up_branch(map, :parallel),
    do: Map.merge(map, %{"branch_name" => "dev", "label" => "dev"})
  defp set_up_branch(map, _mode),
    do: Map.merge(map, %{"branch_name" => "master", "label" => "master"})


  defp start_running_loopers() do
    []
    # Ppls Loopers
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
    # PplSubInits Loopers
    |> Test.Helpers.start_sub_init_loopers()
    # PplBlocks Loopers
    |> Test.Helpers.start_ppl_block_loopers()
    # Blocks Loopers
    |> Test.Helpers.start_block_loopers()
  end
end
