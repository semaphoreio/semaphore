defmodule Ppl.Ppls.STMHandler.Common do
  @moduledoc """
  Code used by multiple STM handlers
  """

  import Ecto.Query

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias InternalApi.Plumber.Pipeline.State, as: PplState
  alias Ppl.PplBlocks.STMHandler.InitializingState, as: PplBlocksInitializingState
  alias Ppl.PplBlocks.STMHandler.WaitingState, as: PplBlocksWaitingState
  alias Ppl.PplBlocks.STMHandler.RunningState, as: PplBlocksRunningState
  alias InternalApi.Plumber.PipelineEvent
  alias Google.Protobuf.Timestamp
  alias Util.{Proto, ToTuple}

  @doc """
  Sends termination reguest based on given auto_cancel strategy with "strategy"
  as value of termination_request_desc field and returns function for transition to
  given exit_state.
  """
  def do_auto_cancel(ppl, ac_strategy, exit_state) do
    case PplsQueries.terminate(ppl, ac_strategy, "strategy") do
      {:ok, ppl} ->
        terminate_pipeline(ppl, exit_state)
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  @doc """
  Called each time pipeline transitions to done state.
  """
  def pipeline_done(data) do
    Wormhole.capture(fn -> notify_gofer(data) end, timeout: 300)

    ppl_id = data.exit_transition.ppl_id

    fn query -> query |> where(ppl_id: ^ppl_id) end
    |> Ppl.AfterPplTasks.STMHandler.WaitingState.execute_now_with_predicate()

    data |> Map.get(:user_exit_function) |> send_state_watch_metric()
  end

  defp notify_gofer(data) do
    ppl_id = data.exit_transition.ppl_id
    result = data.user_exit_function.result
    result_reason = Map.get(data.user_exit_function, :result_reason, "")
    with {:ok, ppl_req}  <- PplRequestsQueries.get_by_id(ppl_id),
         {:ok, _message} <- GoferClient.pipeline_done(ppl_req.switch_id, result, result_reason),
    do: :ok
  end

  defp send_state_watch_metric(data) do
    state = Map.get(data, :state, "")
    result = Map.get(data, :result, "")
    reason = Map.get(data, :result_reason, "")

    internal_metric_name =
      {"StateWatch.events_per_state", ["Ppls", state, concat(result, reason)]}

    external_metric_name = {"Pipelines.state", [state: state, result: concat(result, reason)]}
    Watchman.increment(internal: internal_metric_name, external: external_metric_name)
  end

  defp concat(result, reason) do
    to_str(result) <> "-" <> to_str(reason)
  end

  defp to_str(nil), do: ""
  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)

  @doc """
  Used to trigger all PplBlock loopers for blocks of given pipeline when they
  are to be run or terminated
  """
  def trigger_ppl_block_loopers(data) do

    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    case PplRequestsQueries.get_by_id(ppl_id) do

     {:ok, ppl_req} ->

       0..(ppl_req.block_count - 1)
       |> Enum.map(fn index ->
         trigger_loopers(ppl_id, index)
       end)

      _ -> :nothing
    end
  end

  defp trigger_loopers(ppl_id, index) do
    import Ecto.Query

    query_fun =
      fn query ->
        query |> where(ppl_id: ^ppl_id) |> where(block_index: ^index)
      end

    query_fun |> PplBlocksInitializingState.execute_now_with_predicate()
    query_fun |> PplBlocksRunningState.execute_now_with_predicate()

    # since waiting state has differen 'enter_scheduling' query,
    # predicate in not needed and will not work
    PplBlocksWaitingState.execute_now()
  end

  @doc """
  Terminate pipeline and all of it's blocks
  """
  def terminate_pipeline(ppl, exit_state) do
    with {:ok, tl}  <- TimeLimitsQueries.get_by_id(ppl.ppl_id),
         {:ok, _tl} <- TimeLimitsQueries.terminate(tl, ppl.terminate_request,
                                                 ppl.terminate_request_desc)
    do
      terminate_blocks(ppl, exit_state)
    else
      {:error, "Time limit for pipeline with id:" <> _rest} ->
        terminate_blocks(ppl, exit_state)

      error ->
        {:ok, fn _, _ -> {:error, %{description: %{error: "#{inspect error}"}}} end}
    end
  end

  defp terminate_blocks(ppl, exit_state) do
    case PplBlocksQueries.get_all_by_id(ppl.ppl_id) do
      {:ok, blocks} ->
        blocks |> terminate_all_blocks(ppl) |> to_state(ppl, exit_state)

      {:error, "no ppl blocks for ppl with id" <> _rest} ->
        :ok |> to_state(ppl, exit_state)

      error ->
        {:ok, fn _, _ -> {:error, %{description: %{error: "#{inspect error}"}}} end}
    end
  end

  defp terminate_all_blocks(ppl_blocks, ppl) do
    ppl_blocks
    |> Enum.reduce(:ok, fn block, prev_action -> terminate_block(block, ppl, prev_action) end)
  end

  defp terminate_block(block, ppl, :ok) do
    with {:ok, tl}  <- TimeLimitsQueries.get_by_id_and_index(ppl.ppl_id, block.block_index),
         {:ok, _tl} <- TimeLimitsQueries.terminate(tl, ppl.terminate_request,
                                                 ppl.terminate_request_desc)
    do
      terminate_block_(ppl, block)
    else
      {:error, "Time limit for block " <> _rest} ->
        terminate_block_(ppl, block)

      error -> error
    end
  end
  defp terminate_block(_block, _ppl, error), do: error

  defp terminate_block_(ppl, block) do
    block
    |> PplBlocksQueries.terminate(ppl.terminate_request, ppl.terminate_request_desc)
    |> case do
         {:ok, _ppl_blk} -> :ok
         error -> error
       end
  end

  defp to_state(:ok, ppl, "stopping") do
    PplTracesQueries.set_timestamp(ppl.ppl_id, :stopping_at)
    {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}
  end
  defp to_state(:ok, ppl, "done") do
    reason = determin_reason(ppl)
    PplTracesQueries.set_timestamp(ppl.ppl_id, :done_at)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  defp to_state(error, _ppl, _exit_state) do
    {:ok, fn _, _ -> {:error, %{description: %{error: "#{inspect error}"}}} end}
  end

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(%{terminate_request_desc: "time_limit_exceeded"}), do: "timeout"
  defp determin_reason(_), do: "internal"

  @doc """
  When called publishes state transition event to RabbitMQ
  """
  def publisher_callback(params) do
    with tf                     <- %{Timestamp => {__MODULE__, :date_time_to_timestamps},
                                     PplState =>{__MODULE__, :string_to_enum_atom}},
         {:ok, event}           <- Proto.deep_new(PipelineEvent, params, transformations: tf),
         encoded_event          <- PipelineEvent.encode(event),
         {:ok, exchange_params} <- prepare_exchange_params(params.state)
    do
      {:ok, encoded_event, exchange_params}
    end
  end

  defp prepare_exchange_params(state) do
    %{
      url: System.get_env("RABBITMQ_URL"),
      exchange: "pipeline_state_exchange",
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
  def string_to_enum_atom(_, _), do: PplState.key(0)
end
