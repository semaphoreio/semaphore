defmodule  Block.Tasks.StateResidency do
  @moduledoc """
  Looper which periodicaly sends data about duration of residency in current state
  for each task which is running to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:block, :state_residency_sleep_period_ms)

  use Looper.StateResidency,
    period_ms: @sleep_period,
    repo: Block.EctoRepo,
    schema_name: Block.Tasks.Model.Tasks,
    schema: "block_builds",
    schema_id: :block_id,
    included_states: ~w(pending running),
    trace_schema: "block_builds",
    trace_schema_id: :block_id,
    states_to_timestamps_map:
    %{
      "pending"  => :inserted_at,
      "running"  => :inserted_at
    }

end
