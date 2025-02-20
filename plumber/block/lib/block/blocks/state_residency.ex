defmodule  Block.Blocks.StateResidency do
  @moduledoc """
  Looper which periodicaly sends data about duration of residency in curren state
  for each block which is running to InfluxDB so it can be shown on Grafana.
  """

  @sleep_period Application.compile_env!(:block, :state_residency_sleep_period_ms)

  use Looper.StateResidency,
    period_ms: @sleep_period,
    repo: Block.EctoRepo,
    schema_name: Block.Blocks.Model.Blocks,
    schema: "blocks",
    schema_id: :block_id,
    included_states: ~w(initializing running),
    trace_schema: "blocks",
    trace_schema_id: :block_id,
    states_to_timestamps_map:
    %{
      "initializing" => :inserted_at,
      "running"      => :inserted_at
    }

end
