defmodule Ppl.E2E.ParallelismSupport.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions
  alias InternalApi.Plumber.Pipeline.{Result, ResultReason}

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "Pipeline with parallelism in job definition passes" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "27_parallelism"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 7_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "passed"

    assert {:ok, _, [block]} = %{ppl_id: ppl_id, detailed: true} |> Actions.describe()
    assert length(block.jobs) == 4
  end

  @tag :integration
  test "Pipeline with both parallelism and matrix in same job definition fails" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "27_parallelism", "file_name" => "both-matrix-and-parallelism.fail.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 7_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
  end
end
