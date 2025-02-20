defmodule Looper.StateResidency do
  @moduledoc """
  Looper which periodically sends metrics about how long entity resides in current
  state for each entity in state different from excluded states.
  """

  alias Looper.Util

  defmacro __using__(opts) do
    period_ms         = Util.get_mandatory_field(opts, :period_ms)
    repo              = Util.get_mandatory_field(opts, :repo)
    schema_name       = Util.get_mandatory_field(opts, :schema_name)
    schema            = Util.get_mandatory_field(opts, :schema)
    schema_id         = Util.get_mandatory_field(opts, :schema_id)
    included_states   = Util.get_mandatory_field(opts, :included_states)
    trace_schema      = Util.get_mandatory_field(opts, :trace_schema)
    trace_schema_id   = Util.get_mandatory_field(opts, :trace_schema_id)
    states_to_timestamps_map = Util.get_mandatory_field(opts, :states_to_timestamps_map)

    quote do

      use Looper.Periodic,
        period_ms: unquote(period_ms),
        metric_name: {"StateResidency.wake_up", [Util.get_alias(unquote(schema_name))]},
        args: args()

        def recurring(args) do
          alias Looper.StateResidency.Impl
          Impl.body(args)
        end

        defp args() do %{
          repo:                     unquote(repo),
          schema_name:              unquote(schema_name),
          schema:                   unquote(schema),
          schema_id:                unquote(schema_id),
          included_states:          unquote(included_states),
          trace_schema:             unquote(trace_schema),
          trace_schema_id:          unquote(trace_schema_id),
          states_to_timestamps_map: unquote(states_to_timestamps_map),
        }
        end

    end
  end
end
