defmodule Ppl.PplSubInits.StateWatch do
  @moduledoc """
  Looper which periodically counts PplSubInits in each state and sends those
  results to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:ppl, :state_watch_sleep_period_ms)

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Ppl.EctoRepo,
    schema: Ppl.PplSubInits.Model.PplSubInits,
    included_states: ~w(created fetching compilation stopping regular_init),
    external_metric: "PipelineInitializations.state"

end
