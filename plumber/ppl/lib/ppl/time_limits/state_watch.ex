defmodule Ppl.TimeLimits.StateWatch do
  @moduledoc """
  Looper which periodically counts TimeLimits in each state and sends those
  results to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:ppl, :state_watch_sleep_period_ms)

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Ppl.EctoRepo,
    schema: Ppl.TimeLimits.Model.TimeLimits,
    included_states: ~w(tracking)

end
