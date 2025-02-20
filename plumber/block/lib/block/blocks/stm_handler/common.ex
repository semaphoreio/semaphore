defmodule Block.Blocks.STMHandler.Common do
  @moduledoc """
  Common functions any Manager's Handler can use
  """

  alias Block.Blocks.Model.BlocksQueries
  alias Block.Tasks.Model.TasksQueries
  alias LogTee, as: LT
  alias Util.Metrics

  @metric_name "Ppl.task_block_overhead"

  @doc """
  Notifies PplBlock that particular Block transitioned to 'done'.
  """
  def notify_ppl_block_when_done(data) do
    import Ecto.Query

    block_req = data |> block_request()

    ppl_id = block_req.ppl_id
    block_index = block_req.pple_block_index

    fn query ->
      query |> where(ppl_id: ^ppl_id) |> where(block_index: ^block_index)
    end
    |> done_notification_callback()
  end

  defp block_request(data) do
    data
    |> Map.get(:exit_transition)
    |> BlocksQueries.preload_request()
    |> Map.get(:block_requests)
  end

  defp done_notification_callback(predicate) do
    {m, f} = Application.get_env(:block, :block_done_notification_callback,
      {":block_done_notification_callback not defined", ""})

    apply(m, f, [predicate])
  end

  @doc """
  Increases the counter of done blocks per minute which is used for Grafanna
  visualization and alarms.
  """
  def send_state_watch_metric(data) do
    state = Map.get(data, :state, "")
    result = Map.get(data, :result, "")
    reason = Map.get(data, :result_reason, "")
    Watchman.increment({"StateWatch.events_per_state",
                       ["Blocks", state, concat(result, reason)]})
  end

  defp concat(result, reason) do
    to_str(result) <> "-" <> to_str(reason)
  end

  defp to_str(nil), do: ""
  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)

  @doc """
  Calculates overhead difference betwen finishing Task and finishing Block
  and reports it as a metric
  """
  def send_metrics(data, module) do
    block_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:block_id)

    task = block_id |> TasksQueries.get_by_id()

    block_done_at =
      data
      |> Map.get(:exit_transition, %{})
      |> Map.get(:updated_at)
      |> DateTime.from_naive("Etc/UTC")

    send_metrics_(task, block_done_at, module)
  end

  defp send_metrics_({:ok, task}, {:ok, block_done_at}, module) do
      {:ok, task_done_at} = task.updated_at |> DateTime.from_naive("Etc/UTC")

      diff = DateTime.diff(block_done_at, task_done_at, :millisecond)

      {@metric_name, [Metrics.dot2dash(module)]}
      |> Watchman.submit(diff, :timing)
  end

  defp send_metrics_(task, block_done_at, module)  do
    {task, block_done_at}
    |> LT.warn("Error when sending overhead metrics from #{module}:  ")
  end
end
