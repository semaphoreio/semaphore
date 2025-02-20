defmodule Ppl.Ppls.StateWatch do
  @moduledoc """
  Looper which periodically counts Ppls in each state and sends those results
  to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:ppl, :state_watch_sleep_period_ms)

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Ppl.EctoRepo,
    schema: Ppl.Ppls.Model.Ppls,
    included_states: ~w(initializing pending queuing running stopping),
    external_metric: "Pipelines.state"

end
