defmodule  Ppl.Looper.PplBlocks.STMHandler.Filters.Test do
  use Ppl.IntegrationCase

  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias InternalApi.Plumber.Pipeline.Result
  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  @tag :integration
  test "no filters for given label - block executed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "block_filters.yml",
        "label" => "master"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 15_000)

    assert ppl.result == "failed"
    assert {:ok, blk_2} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)
    assert blk_2.result == "failed"
    assert blk_2.result_reason == "test"

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "skip filter for given label - block skipped" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "block_filters.yml",
        "label" => "dev-test"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 15_000)

    assert ppl.result == "passed"
    assert {:ok, blk_2} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)
    assert blk_2.result == "passed"
    assert blk_2.result_reason == "skipped"

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "execute filter for given label - block executed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "block_filters.yml",
        "label" => "dev-execute-dpl"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 15_000)

    assert ppl.result == "failed"
    assert {:ok, blk_2} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)
    assert blk_2.result == "failed"
    assert blk_2.result_reason == "test"

    Test.Helpers.stop_all_loopers(loopers)
  end
end
