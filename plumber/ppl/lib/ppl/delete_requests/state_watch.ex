defmodule Ppl.DeleteRequests.StateWatch do
  @moduledoc """
  Looper which periodically counts DeleteRequests in each state and sends those
  results to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:ppl, :state_watch_sleep_period_ms)

  use Looper.StateWatch,
    id: __MODULE__,
    period_ms: @sleep_period,
    repo: Ppl.EctoRepo,
    schema: Ppl.DeleteRequests.Model.DeleteRequests,
    terminal_state: "done",
    included_states: ~w(pending deleting queue_deleting)

end
