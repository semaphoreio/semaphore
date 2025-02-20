defmodule Looper.StateWatch do
  @moduledoc """
  Looper which periodically counts events in each state and sends those results
  to InfluxDB so it can be shown on Grafana.
  """

  alias Looper.Util

  defmacro __using__(opts) do
    period_ms         = Util.get_mandatory_field(opts, :period_ms)
    repo              = Util.get_mandatory_field(opts, :repo)
    schema            = Util.get_mandatory_field(opts, :schema)
    included_states   = Util.get_mandatory_field(opts, :included_states)
    external_metric   = Util.get_optional_field(opts, :external_metric, :skip)

    quote do

      use Looper.Periodic,
        period_ms: unquote(period_ms),
        metric_name: {"StateWatch.wake_up", [Util.get_alias(unquote(schema))]},
        args: args()

        def recurring(args) do
          alias Looper.StateWatch.Impl
          Impl.body(args)
        end

        defp args() do %{
          repo:              unquote(repo),
          schema:            unquote(schema),
          included_states:   unquote(included_states),
          external_metric:   unquote(external_metric)
        }
        end

    end
  end
end
