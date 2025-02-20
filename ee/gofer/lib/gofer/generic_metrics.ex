defmodule Gofer.GenericMetrics do
  @moduledoc """
  Generic metric collector

  Periodically loads metrics and sends them via Watchman to InfluxDB.

  Required arguments for the start_link/2 function (provided as a keyword):
  - metric_prefix     - prefix applied to any metric
  - module            - module implementing GenericMetrics behaviour
  """

  @doc """
  Returns milliseconds to schedule the next metrics report
  """
  @callback schedule_interval(DateTime.t()) :: non_neg_integer()

  @doc """
  Returns a list of metrics to report

  Metrics are keyword list with tuple pair as a value:
  - first argument:   zero-argument function that returns value to report
  - second argument:  metric type (:count | :timing | :gauge)
  """
  @callback metrics() :: Keyword.t()

  defmacro __using__(_opts) do
    quote do
      use GenServer

      defdelegate init(args), to: Gofer.GenericMetrics
      defdelegate handle_info(msg, state), to: Gofer.GenericMetrics
    end
  end

  def start_link(module, args) do
    GenServer.start_link(module, args, name: module)
  end

  def init(args) do
    state = Map.new(args)
    schedule_next(state)
    {:ok, state}
  end

  def handle_info(:report_metrics, state = %{module: module}) do
    for {metric_name, {metric_fun, metric_type}} <- module.metrics() do
      full_metric_key = "#{state.metric_prefix}.#{metric_name}"
      Watchman.submit(full_metric_key, metric_fun.(), metric_type)
    end

    {:noreply, state}
  rescue
    error ->
      log_failure(module, error)
      {:noreply, state}
  after
    schedule_next(state)
  end

  defp log_failure(module, error),
    do: LogTee.warn(error, "#{module} report metrics failure")

  defp schedule_next(%{module: module}) do
    interval = module.schedule_interval(DateTime.utc_now())
    Process.send_after(self(), :report_metrics, interval)
  end
end
