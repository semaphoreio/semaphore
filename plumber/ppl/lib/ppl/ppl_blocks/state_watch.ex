defmodule Ppl.PplBlocks.StateWatch do
  @moduledoc """
  Looper which periodically counts PplBlocks in each state and sends those
  results to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:ppl, :state_watch_sleep_period_ms)

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Ppl.EctoRepo,
    schema: Ppl.PplBlocks.Model.PplBlocks,
    included_states: ~w(initializing waiting running stopping),
    external_metric: "Blocks.state"

end
