defmodule Ppl.AfterPplTasks.STMHandler.RunningStateStateTest do
  use Ppl.IntegrationCase, async: false

  import Mock

  alias Test.Helpers, as: TestHelper
  alias Ppl.Actions
  alias Ppl.AfterPplTasks.Model.AfterPplTasksQueries
  alias Ppl.AfterPplTasks.STMHandler.RunningState
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries

  doctest Ppl.AfterPplTasks.STMHandler.RunningState

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    Test.Helpers.truncate_db()
    :ok
  end

  @tag :integration
  test "when after_ppl task is completed, after_ppl transitions to done state" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "30_after_ppl_test"}
      |> TestHelper.schedule_request_factory(:local)
      |> Actions.schedule()

    PplsQueries.get_by_id(ppl_id)
    |> TestHelper.to_state("done", with_traces: true)

    loopers =
      TestHelper.start_ppl_loopers()
      |> TestHelper.start_sub_init_loopers()
      |> Enum.concat([Ppl.AfterPplTasks.STMHandler.WaitingState.start_link()])
      |> Enum.concat([Ppl.AfterPplTasks.STMHandler.PendingState.start_link()])

    TestHelper.wait_for_ppl_state(ppl_id, "done", 5_000)
    :timer.sleep(2_000)

    assert {:ok, after_ppl} = AfterPplTasksQueries.get_by_id(ppl_id)
    assert after_ppl.state == "running"

    :timer.sleep(2_000)

    assert {:ok, "done", "passed"} == Ppl.TaskClient.describe(after_ppl.after_task_id)

    assert {:ok, exit_func} = RunningState.scheduling_handler(after_ppl)
    assert {:ok, %{state: "done", result: "passed"}} == exit_func.(:repo, :changes)

    TestHelper.stop_all_loopers(loopers)
  end
end
