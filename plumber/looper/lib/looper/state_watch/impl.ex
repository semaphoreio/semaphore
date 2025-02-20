defmodule Looper.StateWatch.Impl do
  @moduledoc """
  StateWatch implementation
  """

  alias Looper.Util
  alias LogTee, as: LT
  alias Looper.StateWatch.Query

  def body(params) do
    params
    |> Query.count_events_by_state()
    |> process_result(params)
  end

  defp process_result({:ok, results}, params) when is_list(results) do
    results |> Enum.map(fn result -> result |> send_metric(params) end)
  end

  defp process_result({:error, error}, params) do
    schema = Map.get(params, :schema)
    error |> LT.warn("StateWatch looper failed to count #{schema} with error: ")
  end

  defp send_metric({state, count}, params) do
    schema = Map.get(params, :schema)
    internal_metric_name = {"StateWatch.events_per_state", [Util.get_alias(schema), state]}

    external_metric = Map.get(params, :external_metric)
    if external_metric != :skip do
      external_metric_name = {external_metric, [state: state]}

      Watchman.submit(
        [internal: internal_metric_name, external: external_metric_name],
        count
      )
    else
      Watchman.submit(internal_metric_name, count)
    end
  end

  defp send_metric(error, schema) do
    error |> LT.warn("StateWatch looper failed to count #{schema} with error: ")
  end
end
