defmodule Gofer.CacheMetrics do
  @moduledoc """
  Periodically reports number of different engine processes as a metric on Grafana
  """
  use Gofer.GenericMetrics
  @metric_prefix "Gofer.cache"
  @default_poll_period :timer.minutes(1)

  def start_link(_args) do
    Gofer.GenericMetrics.start_link(__MODULE__,
      metric_prefix: @metric_prefix,
      module: __MODULE__
    )
  end

  def schedule_interval(_now),
    do: Application.get_env(:gofer, :cache_metrics_poll_period, @default_poll_period)

  def metrics do
    Gofer.Cache.cache_configs()
    |> Stream.map(&Keyword.fetch!(&1, :cache_name))
    |> Enum.into([], &cache_size/1)
  end

  defp cache_size(cache_name),
    do: {"#{cache_name}.size", {fn -> Cachex.count!(cache_name) end, :gauge}}
end
