defmodule Looper.Beholder do
  @moduledoc """
  Periodically scans table searching for item stuck in scheduling.

  If item is in scheduling more than '@stuck_threshold_sec'
  Beholder will:
  - move it out of cheduling
  - increment item's recovery counter

  If recovery counter is higher than threshold_count
  item will transition to terminal state.
  """

  alias Elixir.Looper.Util
  alias Looper.Beholder.Impl

  defmacro __using__(opts) do
    id                = Util.get_mandatory_field(opts, :id)
    period_sec        = Util.get_mandatory_field(opts, :period_sec)
    repo              = Util.get_mandatory_field(opts, :repo)
    query             = Util.get_mandatory_field(opts, :query)
    excluded_states   = Util.get_mandatory_field(opts, :excluded_states)
    terminal_state    = Util.get_mandatory_field(opts, :terminal_state)
    result_on_abort   = Util.get_mandatory_field(opts, :result_on_abort)
    result_reason_on_abort = Util.get_optional_field(opts, :result_reason_on_abort, "")
    threshold_sec     = Util.get_mandatory_field(opts, :threshold_sec)
    threshold_count   = Util.get_mandatory_field(opts, :threshold_count)
    callback          = Util.get_optional_field(opts, :callback, :pass)
    external_metric   = Util.get_optional_field(opts, :external_metric, :skip)

    quote do
      use Looper.Periodic,
        period_ms: unquote(period_sec) * 1_000,
        metric_name: Impl.metric_name(unquote(id), "wake_up"),
        args: args()

      def recurring(beholder_cfg) do
        Impl.body(beholder_cfg)
      end

      defp args do %{
        id: unquote(id),
        repo: unquote(repo),
        query: unquote(query),
        excluded_states: unquote(excluded_states),
        terminal_state: unquote(terminal_state),
        result_on_abort: unquote(result_on_abort),
        result_reason_on_abort: unquote(result_reason_on_abort),
        threshold_sec: unquote(threshold_sec),
        threshold_count: unquote(threshold_count),
        callback: unquote(callback),
        external_metric: unquote(external_metric)
      }
      end
    end
  end
end
