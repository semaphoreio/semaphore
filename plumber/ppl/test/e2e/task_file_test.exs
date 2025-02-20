defmodule Ppl.E2E.TaskFile.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "Pipeline with task_file property passes" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "15_task_file"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 7_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "passed"
  end

  @tag :integration
  test "Pipeline with malformed task_file content fails" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "16_task_file_malformed"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 2_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
  end

  @tag :integration
  test "Pipeline with non-existent task_file value" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "17_task_file_nonexistent"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 7_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
    assert String.contains?(ppl.error_description, "is not available")
  end
end
