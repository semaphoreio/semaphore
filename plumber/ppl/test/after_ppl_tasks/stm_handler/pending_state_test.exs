defmodule Ppl.AfterPplTasks.STMHandler.PendingStateTest do
  use Ppl.IntegrationCase, async: false

  import Mock

  alias Test.Helpers, as: TestHelper
  alias Ppl.Actions
  alias Ppl.TaskClient
  alias Ppl.AfterPplTasks.Model.AfterPplTasksQueries
  alias Ppl.AfterPplTasks.STMHandler.PendingState
  alias Ppl.Ppls.Model.PplsQueries

  doctest Ppl.AfterPplTasks.STMHandler.PendingState

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    TestHelper.truncate_db()
    :ok
  end

  @tag :integration
  test "when after_ppl transitions to pending state task is created" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "30_after_ppl_test"}
      |> TestHelper.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers =
      TestHelper.start_ppl_loopers()
      |> TestHelper.start_sub_init_loopers()
      |> Enum.concat([Ppl.AfterPplTasks.STMHandler.WaitingState.start_link()])

    {:ok, ppl} =
      PplsQueries.get_by_id(ppl_id)
      |> TestHelper.to_state("done", with_traces: true)

    TestHelper.wait_for_ppl_state(ppl.ppl_id, "done", 5_000)
    :timer.sleep(2_000)

    {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    assert ppl.with_after_task == true
    assert {:ok, after_ppl} = AfterPplTasksQueries.get_by_id(ppl_id)
    assert after_ppl.state == "pending"
    assert {:ok, exit_func} = PendingState.scheduling_handler(after_ppl)
    assert {:ok, %{state: "running", after_task_id: after_task_id}} = exit_func.(:repo, :changes)
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, %{task: task}} = TaskClient.describe_details(after_task_id)

    assert [
              "Hello",
              "Nameless 1",
              "With parallelism - 1/4",
              "With parallelism - 2/4",
              "With parallelism - 3/4",
              "With parallelism - 4/4",
              "With matrix - FOOS=foo#1, BARS=bar#1",
              "With matrix - FOOS=foo#1, BARS=bar#2",
              "With matrix - FOOS=foo#2, BARS=bar#1",
              "With matrix - FOOS=foo#2, BARS=bar#2",
              "With matrix - FOOS=foo#3, BARS=bar#1",
              "With matrix - FOOS=foo#3, BARS=bar#2"
            ] = Enum.map(task.jobs, & &1.name)

    assert ppl.after_task_id != nil

    TestHelper.stop_all_loopers(loopers)
  end
end
