defmodule Ppl.E2E.ComposeStyleCi.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions
  alias InternalApi.Plumber.Pipeline.Result

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "Pipeline with multiple docker images in agent definition passes" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "26_compose_style_ci"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 7_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "passed"
  end
end
