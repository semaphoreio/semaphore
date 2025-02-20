defmodule Looper.Periodic do
  @moduledoc """
  Execute callback periodically.
  """

  alias Looper.Util, as: Lutil

  defmodule Behaviour do
    @moduledoc false
    @callback recurring(any) :: any
  end

  defmacro __using__(opts) do
    period_ms       = Lutil.get_mandatory_field(opts, :period_ms)
    metric_name     = Lutil.get_mandatory_field(opts, :metric_name)
    wormhole_timeout = Keyword.get(opts, :wormhole_timeout) || 16_000
    args            = opts[:args]

    quote do
      @behaviour Looper.Periodic.Behaviour

      use GenServer

      @doc """
        Recepy for supervisor how to start periodic activity.

        # Example
        Beholder.child_spec()
      """
      def child_spec(opts) do
        id = Keyword.get(opts, :id) || __MODULE__

        %{id: id,
          start: {__MODULE__, :start_link, [id]},
          restart: :permanent,
          shutdown: 5000,
          type: :worker}
      end

      def start_link(name \\ __MODULE__) do
        require Logger

        ["Periodic from module #{__MODULE__} with name #{name} :: ",
        "period: #{unquote(period_ms)} ms, ",
        "metric_name: #{inspect unquote(metric_name)}, ",
        "recurring args: #{inspect unquote(args)}"]
        |> Logger.info()

        GenServer.start_link(__MODULE__, %{}, name: name)
      end

      def stop(server \\ __MODULE__, reason \\ :normal) do
        GenServer.stop(server, reason)
      end

      @doc """
      Invoke callback without scheduling new invocation
      """
      def execute_now(name \\ __MODULE__), do: GenServer.cast(name, :wake_up)

      def init(state) do
        schedule_wake_up_call()
        {:ok, state}
      end

      @doc """
      This handler is called periodically.
      It has to reschedule it self.
      """
      def handle_info(:wake_up, state) do
        call_recurring()
        schedule_wake_up_call()
        {:noreply, state}
      end

      @doc """
      This handler is called by `execute_now` on demand.
      """
      def handle_cast(:wake_up, state) do
        call_recurring()
        {:noreply, state}
      end

      defp call_recurring do
        alias Util.Metrics
        Metrics.benchmark(unquote(metric_name), &call_recurring_/0)
      end

      defp call_recurring_ do
        Wormhole.capture(__MODULE__, :recurring, [unquote(args)],
                         timeout: unquote(wormhole_timeout),
                         stacktrace: true)
      end

      defp schedule_wake_up_call, do:
        Process.send_after(self(), :wake_up, unquote(period_ms))
    end
  end
end
