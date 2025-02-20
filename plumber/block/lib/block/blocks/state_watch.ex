defmodule Block.Blocks.StateWatch do
  @moduledoc """
  Looper which periodicaly counts Blocks in each state and sends those
  results to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:block, :state_watch_sleep_period_ms)

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Block.EctoRepo,
    schema: Block.Blocks.Model.Blocks,
    included_states: ~w(initializing running stopping)

end
