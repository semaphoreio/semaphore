defmodule Ppl.PplSubInits.STMHandler.Common do
  @moduledoc """
  Common functions any Manager's Handler can use
  """

  alias Ppl.PplSubInits.STMHandler

  @doc """
  Increases the counter of done ppl sub inits per minute which is used for Grafanna
  visualization and alarms.
  """
  def send_state_watch_metric(data) do
    state = Map.get(data, :state, "")
    result = Map.get(data, :result, "")
    reason = Map.get(data, :result_reason, "")

    internal_metric_name =
      {"StateWatch.events_per_state", ["PplSubInits", state, concat(result, reason)]}

    external_metric_name = {"PipelineInitializations.state", [state: state, result: concat(result, reason)]}
    Watchman.increment(internal: internal_metric_name, external: external_metric_name)
  end

  defp concat(result, reason) do
    to_str(result) <> "-" <> to_str(reason)
  end

  defp to_str(nil), do: ""
  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)

  def compile_task_done_notification_callback(query_fun) do
    query_fun |> STMHandler.CompilationState.execute_now_with_predicate()
    query_fun |> STMHandler.StoppingState.execute_now_with_predicate()
  end
end
