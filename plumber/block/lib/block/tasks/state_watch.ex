defmodule Block.Tasks.StateWatch do
  @moduledoc """
  Looper which periodicaly counts Tasks in each state and sends those
  results to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:block, :state_watch_sleep_period_ms)

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Block.EctoRepo,
    schema: Block.Tasks.Model.Tasks,
    included_states: ~w(pending running stopping),
    external_metric: "Tasks.state"

end
