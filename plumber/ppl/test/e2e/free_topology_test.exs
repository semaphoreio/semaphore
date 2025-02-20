defmodule Ppl.E2E.FreeTopology.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions
  alias InternalApi.Plumber.Pipeline.Result
  alias Ppl.PplBlocks.Model.PplBlocksQueries

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "Free topology pipeline passes" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 10_000)
    {:ok, _blocks} = PplBlocksQueries.get_all_by_id(ppl_id)

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than(
     __MODULE__, :do_wait_block_status, [ppl_id,
      %{"A" => [state: "running", result: nil], "B" => [state: "waiting", result: nil], "C" => [state: "waiting", result: nil],
       "D" => [state: "running", result: nil], "E" =>[state: "waiting", result: nil]}], 10_000)

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than(
     __MODULE__, :do_wait_block_status, [ppl_id,
      %{"A" => [state: "done", result: "passed"], "B" => [state: "running", result: nil],
       "C" => [state: "waiting", result: nil], "D" => [state: "done", result: "passed"],
       "E" =>[state: "waiting", result: nil]}], 10_000)

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than(
     __MODULE__, :do_wait_block_status, [ppl_id,
      %{"A" => [state: "done", result: "passed"], "B" => [state: "done", result: "passed"],
      "C" => [state: "running", result: nil], "D" => [state: "done", result: "passed"],
      "E" =>[state: "running", result: nil]}], 10_000)


    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "passed"

    {:ok, blocks} = PplBlocksQueries.get_all_by_id(ppl_id)

    Enum.each(blocks, fn block -> assert block.state == "done" end)
    Enum.each(blocks, fn block -> assert block.result == "passed" end)
  end

  @tag :integration
  test "Free topology pipeline with failing block" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "14_free_topology_failing_block"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()


    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 10_000)
    {:ok, _blocks} = PplBlocksQueries.get_all_by_id(ppl_id)

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than(
     __MODULE__, :do_wait_block_status, [ppl_id,
      %{"A" => [state: "running", result: nil], "B" => [state: "waiting", result: nil], "C" => [state: "waiting", result: nil],
       "D" => [state: "running", result: nil], "E" =>[state: "waiting", result: nil]}], 10_000)

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than(
      __MODULE__, :do_wait_block_status, [ppl_id,
      %{"A" => [state: "done", result: "passed"], "B" => [state: "done", result: "canceled"], "C" => [state: "done", result: "canceled"],
        "D" => [state: "done", result: "failed"], "E" =>[state: "done", result: "canceled"]}], 10_000)


    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)

    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"

    ppl_id
    |> PplBlocksQueries.get_all_by_id()
    |> elem(1)
    |> check_result("A", "passed")
    |> check_result("B", "canceled")
    |> check_result("C", "canceled")
    |> check_result("D", "failed")
    |> check_result("E", "canceled")
  end

  @tag :integration
  test "Free topology failing pipeline with fail_fast = cancel" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "18_fail_fast_cancel"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 10_000)

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than( __MODULE__, :do_wait_block_status, [ppl_id,
      %{"A" => [state: "done", result: "passed"],  "B" => [state: "done", result: "passed"],
        "C" => [state: "done", result: "failed"], "D" => [state: "done", result: "canceled"],
        "E" => [state: "done", result: "canceled"]}], 15_000)

    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)

    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
  end

  @tag :integration
  test "Free topology failing pipeline with fail_fast = stop" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "19_fail_fast_stop"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 10_000)

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than( __MODULE__, :do_wait_block_status, [ppl_id,
      %{"A" => [state: "done", result: "stopped"],  "B" => [state: "done", result: "stopped"],
        "C" => [state: "done", result: "failed"], "D" => [state: "done", result: "canceled"],
        "E" => [state: "done", result: "canceled"]}], 15_000)

    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)

    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
  end

  defp check_result(blocks, block_name, expected_result) do
    Enum.find(blocks, fn block -> block.name == block_name end)
    |> do_check_result(expected_result)

    blocks
  end

  defp do_check_result(response, expected_result) do
    assert response.state == "done"
    assert response.result == expected_result
  end

  def do_wait_block_status(ppl_id, desired_status) do
    :timer.sleep 100
    {:ok, blocks} = PplBlocksQueries.get_all_by_id(ppl_id)
    if reached_desired_status?(blocks, desired_status) do
      blocks
    else
      do_wait_block_status(ppl_id, desired_status)
    end
  end


  defp reached_desired_status?(blocks, desired_status) do
    Enum.map(desired_status, fn {k, v} ->
       Enum.find_value(blocks,
       fn block -> block.name == k && block.state == Keyword.get(v, :state) && block.result == Keyword.get(v, :result)
      end)
    end)
    |> Enum.all?(fn(x) -> x != nil end)
  end

end
