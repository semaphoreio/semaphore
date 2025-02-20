defmodule Ppl.AfterPplTasks.STMHandler.WaitingStateTest do
  use Ppl.IntegrationCase, async: false

  alias Test.Helpers, as: TestHelper
  alias Ppl.Actions
  alias Ppl.AfterPplTasks.Model.AfterPplTasksQueries
  alias Ppl.AfterPplTasks.STMHandler.WaitingState
  alias Ppl.Ppls.Model.PplsQueries

  doctest Ppl.AfterPplTasks.STMHandler.WaitingState

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    Test.Helpers.truncate_db()
    :ok
  end

  @tag :integration
  test "when pipeline starts running after_ppl is in waiting state" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "30_after_ppl_test"}
      |> TestHelper.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers =
      TestHelper.start_ppl_loopers()
      |> TestHelper.start_sub_init_loopers()

    TestHelper.wait_for_ppl_state(ppl_id, "running", 5000)
    :timer.sleep(2_000)

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, after_ppl} = AfterPplTasksQueries.get_by_id(ppl_id)
    assert after_ppl.state == "waiting"

    TestHelper.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when pipeline finishes execution after_ppl transitions to pending state" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "30_after_ppl_test"}
      |> TestHelper.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers =
      TestHelper.start_ppl_loopers()
      |> TestHelper.start_sub_init_loopers()

    PplsQueries.get_by_id(ppl_id)
    |> Test.Helpers.to_state("done")

    TestHelper.wait_for_ppl_state(ppl_id, "done", 5_000)
    :timer.sleep(2_000)

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, after_ppl} = AfterPplTasksQueries.get_by_id(ppl_id)
    assert after_ppl.state == "waiting"

    assert {:ok, exit_func} = WaitingState.scheduling_handler(after_ppl)
    assert {:ok, %{state: "pending"}} == exit_func.(:repo, :changes)

    TestHelper.stop_all_loopers(loopers)
  end
end
