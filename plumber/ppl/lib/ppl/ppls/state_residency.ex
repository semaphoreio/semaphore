defmodule Ppl.Ppls.StateResidency do
  @moduledoc """
  Looper which periodicaly sends data about duration of residency in curren state
  for each pipeline which is not done to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:ppl, :state_residency_sleep_period_ms)

  use Looper.StateResidency,
    period_ms: @sleep_period,
    repo: Ppl.EctoRepo,
    schema_name: Ppl.Ppls.Model.Ppls,
    schema: "pipelines",
    schema_id: :ppl_id,
    included_states: ~w(initializing pending queuing running stopping),
    trace_schema: "pipeline_traces",
    trace_schema_id: :ppl_id,
    states_to_timestamps_map:
    %{
      "initializing" => :created_at,
      "pending"      => :pending_at,
      "queuing"      => :queuing_at,
      "running"      => :running_at,
      "stopping"     => :stopping_at,
      "done"         => :done_at
    }

end
