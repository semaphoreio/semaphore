defmodule Ppl.AfterPplTasks.STMHandler.Common do
  @moduledoc """
  Common functions any Manager's Handler can use
  """

  alias Ppl.AfterPplTasks.STMHandler
  alias InternalApi.Plumber.AfterPipelineEvent
  alias InternalApi.Plumber.AfterPipeline.State, as: AfterPplState
  alias Google.Protobuf.Timestamp
  alias Util.{Proto, ToTuple}

  @doc """
  Increases the counter of done after_ppl tasks per minute which is used for Grafanna
  visualization and alarms.
  """
  def send_state_watch_metric(data) do
    state = Map.get(data, :state, "")
    result = Map.get(data, :result, "")
    reason = Map.get(data, :result_reason, "")

    internal_metric_name =
      {"StateWatch.events_per_state", ["AfterPplTasks", state, concat(result, reason)]}

    external_metric_name = {"AfterPipelines.state", [state: state, result: concat(result, reason)]}

    Watchman.increment(internal: internal_metric_name, external: external_metric_name)
  end

  defp concat(result, reason) do
    to_str(result) <> "-" <> to_str(reason)
  end

  defp to_str(nil), do: ""
  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)

  def after_ppl_task_done_notification_callback(query_fun) do
    STMHandler.RunningState.execute_now_with_predicate(query_fun)
  end

  def publisher_callback(params) do
    with tf <- %{
           Timestamp => {__MODULE__, :date_time_to_timestamps},
           AfterPplState => {__MODULE__, :string_to_enum_atom}
         },
         {:ok, event} <- Proto.deep_new(AfterPipelineEvent, params, transformations: tf),
         encoded_event <- AfterPipelineEvent.encode(event),
         {:ok, exchange_params} <- prepare_exchange_params(params.state) do
      {:ok, encoded_event, exchange_params}
    end
  end

  defp prepare_exchange_params(state) do
    %{
      url: System.get_env("RABBITMQ_URL"),
      exchange: "after_pipeline_state_exchange",
      routing_key: state
    }
    |> ToTuple.ok()
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

  def string_to_enum_atom(_, _), do: AfterPplState.key(0)
end
