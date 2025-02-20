defmodule Ppl.AfterPplTasks.StateResidency do
  @moduledoc """
  Looper which periodically counts AfterPplTasks in each state and sends those
  results to InfluxDB so it can be shown on Grafana.
  """
  alias Ppl.AfterPplTasks.Model.AfterPplTasks

  @sleep_period Application.compile_env!(:ppl, :state_watch_sleep_period_ms)

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Ppl.EctoRepo,
    schema: AfterPplTasks,
    included_states: ~w(waiting pending running)
end
