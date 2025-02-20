defmodule Ppl.TimeLimits.Model.TrackingStateScheduling.Test do
  use ExUnit.Case

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.TimeLimits.Model.TrackingStateScheduling, as: Query

  setup do
    Test.Helpers.truncate_db()

    :ok
  end

  test "if no deadlines are reached query returns empty list" do
    _time_limts =
      [{5, -1}, {7, -1}, {9, 0}, {11, 1}]
      |> Enum.map(fn {limit, index} ->
        type = if index >= 0, do: "ppl_block", else: "pipeline"

        insert_time_limit(type, limit, index)
      end)

    assert {:ok, []} == Query.get_deadline_reached("pipeline")
    assert {:ok, []} == Query.get_deadline_reached("ppl_block")
  end

  test "query returns time limit which deadline is reached" do
    time_limts =
      [{5, -1}, {-4, -1}, {3, 0}, {-2, 1}]
      |> Enum.map(fn {limit, index} ->
        type = if index >= 0, do: "ppl_block", else: "pipeline"

        insert_time_limit(type, limit, index)
      end)

    assert {:ok, [{result, _old}]} = Query.get_deadline_reached("pipeline")
    assert result.id == time_limts |> Enum.at(1) |> Map.get(:id)

    assert {:ok, [{result, _old}]} = Query.get_deadline_reached("ppl_block")
    assert result.id == time_limts |> Enum.at(3) |> Map.get(:id)
  end

  test "query returns time limit which termination was requested" do
    time_limts =
      [{5, -1}, {7, -1}, {9, 0}, {11, 1}]
      |> Enum.map(fn {limit, index} ->
        type = if index >= 0, do: "ppl_block", else: "pipeline"

        insert_time_limit(type, limit, index)
      end)

    assert {:ok, []} == Query.get_deadline_reached("pipeline")
    assert {:ok, []} == Query.get_deadline_reached("ppl_block")

    assert {:ok, tl} = time_limts |> Enum.at(1) |> TimeLimitsQueries.terminate("stop", "API call")

    assert {:ok, [{result, _old}]} = Query.get_deadline_reached("pipeline")
    assert result.id == tl.id
    assert {:ok, []} == Query.get_deadline_reached("ppl_block")

    assert {:ok, tl} = time_limts |> Enum.at(3) |> TimeLimitsQueries.terminate("stop", "API call")

    assert {:ok, [{result, _old}]} = Query.get_deadline_reached("ppl_block")
    assert result.id == tl.id
  end

  defp insert_time_limit(type, limit, index) do
    assert request_args = Test.Helpers.schedule_request_factory(:local)
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    assert {:ok, ppl} = PplsQueries.insert(ppl_req)

    ppl = Map.merge(ppl, %{exec_time_limit_min: limit})
    ppl = if type == "pipeline", do: ppl, else: Map.merge(ppl, %{block_index: index})

    assert {:ok, tl} = TimeLimitsQueries.set_time_limit(ppl, type)

    tl
  end
end
