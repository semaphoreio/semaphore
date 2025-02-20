defmodule Rbac.Toolbox.Periodic do
  defmodule Behaviour do
    @callback perform() :: any
    @callback perform(any) :: any
  end

  defmacro __using__(_) do
    quote do
      @behaviour Rbac.Toolbox.Periodic.Behaviour

      use GenServer

      def child_spec(opts) do
        id = Keyword.get(opts, :id) || __MODULE__

        %{
          id: id,
          start: {__MODULE__, :start_link, [id]},
          restart: :permanent,
          shutdown: 5000,
          type: :worker
        }
      end

      def start_link(name \\ __MODULE__) do
        GenServer.start_link(__MODULE__, %{}, name: name)
      end

      def perform_now, do: perform_now(__MODULE__, [])
      def perform_now(args), do: perform_now(__MODULE__, args)
      def perform_now(name, args), do: Process.send_after(name, {:work, args}, 1)

      def init(state) do
        require Logger
        Logger.info("Starting Periodic Worker #{__MODULE__} (naptime: #{state.naptime}ms)")

        schedule_work(state)

        {:ok, state}
      end

      def handle_info({:work, args}, state) do
        do_work(args, state)

        {:noreply, state}
      end

      def handle_info({:work_and_schedule, args}, state) do
        do_work(args, state)

        schedule_work(state)

        {:noreply, state}
      end

      def handle_info(e, state) do
        {:noreply, state}
      end

      defp do_work(args, state) do
        Watchman.benchmark("#{state.name}.perform.duration", fn ->
          if args != [] do
            Wormhole.capture(__MODULE__, :perform, [args],
              timeout: state.timeout,
              stacktrace: true
            )
          else
            Wormhole.capture(__MODULE__, :perform, [], timeout: state.timeout, stacktrace: true)
          end
        end)
      end

      defp schedule_work(state) do
        Process.send_after(self(), {:work_and_schedule, []}, state.naptime)
      end

      def stop(server \\ __MODULE__, reason \\ :normal), do: GenServer.stop(server, reason)

      defoverridable init: 1
    end
  end
end
