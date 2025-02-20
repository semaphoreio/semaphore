defmodule Ppl.E2E.RunBlock.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "when there is run in block definition => blocks are run or skipped according to condition" do
    loopers = Test.Helpers.start_all_loopers()

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "run_block.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    assert ppl.result == "passed"

    Test.Helpers.stop_all_loopers(loopers)

    assert {:ok, _, blocks} = %{ppl_id: ppl_id, detailed: true} |> Actions.describe()
    assert blocks |> Enum.at(0) |> Map.get(:result_reason) == nil
    assert blocks |> Enum.at(1) |> Map.get(:result_reason) == "skipped"
    assert blocks |> Enum.at(2) |> Map.get(:result_reason) == "skipped"
  end
end
