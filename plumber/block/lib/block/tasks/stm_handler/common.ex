defmodule Block.Tasks.STMHandler.Common do
  @moduledoc """
  Common functions any Manager's Handler can use
  """

  alias Block.Blocks.STMHandler.StoppingState, as: BlocksStoppingState
  alias Block.Blocks.STMHandler.RunningState, as: BlocksRunningState
  alias LogTee, as: LT
  alias Util.Metrics

  @metric_name "Ppl.zebra_plumber_overhead"

  def task_api_url, do: System.get_env("INTERNAL_API_URL_TASK")

  @doc """
  Notifies Block that particular Task transitioned to 'done'.
  """
  def notify_block_when_done(data) do
    import Ecto.Query

    block_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:block_id)

    query_fun = fn query -> query |> where(block_id: ^block_id) end

    query_fun |> BlocksStoppingState.execute_now_with_predicate()
    query_fun |> BlocksRunningState.execute_now_with_predicate()
  end

  @doc """
  Increases the counter of done tasks per minute which is used for Grafanna
  visualization and alarms.
  """
  def send_state_watch_metric(data) do
    state = Map.get(data, :state, "")
    result = Map.get(data, :result, "")
    reason = Map.get(data, :result_reason, "")

    internal_metric_name =
      {"StateWatch.events_per_state", ["Tasks", state, concat(result, reason)]}

    external_metric_name = {"Tasks.state", [state: state, result: concat(result, reason)]}

    Watchman.increment(internal: internal_metric_name, external: external_metric_name)
  end

  defp concat(result, reason) do
    to_str(result) <> "-" <> to_str(reason)
  end

  defp to_str(nil), do: ""
  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)

  @doc """
  Calculates overhead difference betwen finishing Task on Zebra and in Plumber
  and reports it as a metric
  """
  def send_metrics(data = %{user_exit_function: %{description: desc}}, module) do
    zebra_done_at = desc |> Map.get(:task, %{}) |> Map.get(:finished_at)

    plumber_done_at =
      data
      |> Map.get(:exit_transition, %{})
      |> Map.get(:updated_at)
      |> DateTime.from_naive("Etc/UTC")

    send_metrics_(zebra_done_at, plumber_done_at, module)
  end

  defp send_metrics_(zebra_done_at, {:ok, plumber_done_at}, module)
    when not is_nil(zebra_done_at) do
      diff = DateTime.diff(plumber_done_at, zebra_done_at, :millisecond)

      {@metric_name, [Metrics.dot2dash(module)]}
      |> Watchman.submit(diff, :timing)
  end

  defp send_metrics_(zebra_done_at, plumber_done_at, module)  do
    {zebra_done_at, plumber_done_at}
    |> LT.warn("Error when sending overhead metrics from #{module}:  ")
  end
end
