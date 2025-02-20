defmodule Looper.StateResidency.Impl do
  @moduledoc """
  StateResidency implementation
  """

  alias Looper.Util
  alias LogTee, as: LT
  alias Looper.StateResidency.Query

  def body(params) do
    params.included_states
    |> Enum.map(fn state ->
      params
      |> Query.get_durations_for_state(state)    
      |> process_result(params)
    end)
  end

  defp process_result({:ok, result}, params) do
    schema_name = Map.get(params, :schema_name)
    {state, result} = Map.pop(result, :state)
    result
    |> Enum.map(fn {key, value} ->
      send_metrics(key, value, state, schema_name)
     end)
  end
  defp process_result({:error, error}, params) do
    schema_name = Map.get(params, :schema_name) |> Util.get_alias()
    error |> LT.warn("StateResidency looper failed to measure residency duration for #{schema_name}: ")
  end

  defp send_metrics(metric_type, duration, state, schema_name) do
    Watchman.submit({"StateResidency.duration_per_state",
      [Util.get_alias(schema_name), state, metric_type]}, duration)
  end
end
