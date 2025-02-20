defmodule Ppl.AfterPplTasks.StateWatch do
  @moduledoc """
  Looper which periodically counts AfterPplTasks in each state and sends those results
  to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:ppl, :state_watch_sleep_period_ms)

  alias Ppl.AfterPplTasks.Model.AfterPplTasks

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Ppl.EctoRepo,
    schema: AfterPplTasks,
    included_states: ~w(waiting pending running stopping),
    external_metric: "AfterPipelines.state"
end
