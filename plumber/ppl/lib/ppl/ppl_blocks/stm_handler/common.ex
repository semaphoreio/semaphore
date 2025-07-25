defmodule Ppl.PplBlocks.STMHandler.Common do
  @moduledoc """
  Code used by multiple STM handlers
  """

  alias InternalApi.Plumber.Block.State, as: PplBlockState
  alias Ppl.Ppls.STMHandler.RunningState, as: PplRunningState
  alias Ppl.Ppls.STMHandler.StoppingState, as: PplStoppingState
  alias InternalApi.Plumber.PipelineBlockEvent
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.PplBlocks.STMHandler.RunningState, as: PplBlocksRunningState
  alias Ppl.PplBlocks.STMHandler.StoppingState, as: PplBlocksStoppingState
  alias Google.Protobuf.Timestamp
  alias Util.{Proto, ToTuple, Metrics}
  alias LogTee, as: LT

  @metric_name "Ppl.block_ppl_block_overhead"

  @doc """
  Used for determining result_reason for terminated ppl_block based on
  terminate_request_desc field.
  """
  def determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  def determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  def determin_reason(%{terminate_request_desc: "fast_failing"}), do: "fast_failing"
  def determin_reason(%{terminate_request_desc: "time_limit_exceeded"}), do: "timeout"
  def determin_reason(_), do: "internal"

  @doc """
  Sends termination reguest based on given fast-failing strategy with "fast_failing"
  as value of termination_request_desc field and returns function for transition to
  given exit_state.
  """
  def do_fast_failing(ppl_blk, ff_strategy, exit_state) do
    case PplBlocksQueries.terminate(ppl_blk, ff_strategy, "fast_failing") do
      {:ok, _} ->
        {:ok, fn _, _ -> {:ok, %{state: exit_state}} end}
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  @doc """
  Called from block service to notify particular PplBlock that its Block is done
  """
  def block_done_notification_callback(query_fun) do
    query_fun |> PplBlocksRunningState.execute_now_with_predicate()
    query_fun |> PplBlocksStoppingState.execute_now_with_predicate()
  end

  @doc """
  Used for publishing state change events on RabbitMQ
  """
  def publisher_callback(params) do
    with tf                     <- %{Timestamp => {__MODULE__, :date_time_to_timestamps},
                                     PplBlockState =>{__MODULE__, :string_to_enum_atom}},
         {:ok, event}           <- Proto.deep_new(PipelineBlockEvent, params, transformations: tf),
         encoded_event          <- PipelineBlockEvent.encode(event),
         {:ok, exchange_params} <- prepare_exchange_params(params.state)
    do
      {:ok, encoded_event, exchange_params}
    end
  end

  defp prepare_exchange_params(state) do
    %{
      url: System.get_env("RABBITMQ_URL"),
      exchange: "pipeline_block_state_exchange",
      routing_key: state,
    } |> ToTuple.ok()
  end

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}
  def date_time_to_timestamps(_field_name, date_time) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  def string_to_enum_atom(_field_name, field_value)
    when is_binary(field_value) and field_value != "" do
      field_value |> String.upcase() |> String.to_atom()
  end
  def string_to_enum_atom(_, _), do: PplBlockState.key(0)

  @doc """
  Notifies Ppl that particular PplBlock transitioned to 'done'.
  """
  def notify_ppl_when_done(data) do
    import Ecto.Query

    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    query_fun = fn query -> query |> where(ppl_id: ^ppl_id) end

    query_fun |> PplRunningState.execute_now_with_predicate()
    query_fun |> PplStoppingState.execute_now_with_predicate()
  end

  @doc """
  Calculates overhead difference betwen finishing Block in Block app and
  finishing PplBlock in Ppl app and reports it as a metric
  """
  def send_metrics(data, module) do
    block_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:block_id)

    block = block_id |> Block.status()

    ppl_blk_done_at =
      data
      |> Map.get(:exit_transition, %{})
      |> Map.get(:updated_at)
      |> DateTime.from_naive("Etc/UTC")

    send_metrics_(block, ppl_blk_done_at, module)

    # if block timed-out then also send timeout overhead
    send_timeout_overhead(data, ppl_blk_done_at, module)
  end

  defp send_metrics_({:ok, block}, {:ok, ppl_blk_done_at}, module) do
      diff = DateTime.diff(ppl_blk_done_at, block.updated_at, :millisecond)

      {@metric_name, [Metrics.dot2dash(module)]}
      |> Watchman.submit(diff, :timing)
  end

  defp send_metrics_(block, ppl_blk_done_at, module)  do
    {block, ppl_blk_done_at}
    |> LT.warn("Error when sending overhead metrics from #{module}:  ")
  end

  defp send_timeout_overhead(data = %{user_exit_function: %{result_reason: "timeout"}}, {:ok, done_at}, module) do
    ppl_id = data.exit_transition.ppl_id
    block_index = data.exit_transition.block_index
    case TimeLimitsQueries.get_by_id_and_index(ppl_id, block_index) do
      {:ok, tl} ->
        diff = DateTime.diff(done_at, tl.deadline, :millisecond)
        {"Ppl.ppl_blk_timeout_overhead", [module]} |> Watchman.submit(diff, :timing)

      # skip sending metrics since termination was tirrgered because of
      # pipeline level execution time limit
      _error -> :continue
    end
  end
  defp send_timeout_overhead(_data, _done_at, _module), do: :continue

  @doc """
  Increases the counter of done ppl blocks per minute which is used for Grafanna
  visualization and alarms.
  """
  def send_state_watch_metric(data) do
    state = Map.get(data, :state, "")
    result = Map.get(data, :result, "")
    reason = Map.get(data, :result_reason, "")
    internal_metric_name = {"StateWatch.events_per_state",
                       ["PplBlocks", state, concat(result, reason)]}
    external_metric_name = {"Blocks.state", [state: state, result: concat(result, reason)]}
    Watchman.increment(internal: internal_metric_name, external: external_metric_name)
  end

  defp concat(result, reason) do
    to_str(result) <> "-" <> to_str(reason)
  end

  defp to_str(nil), do: ""
  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)
end
