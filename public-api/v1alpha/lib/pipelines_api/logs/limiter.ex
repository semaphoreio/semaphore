defmodule PipelinesAPI.Logs.Limiter do
  @moduledoc """
  Caps how many job logs this pod streams at once. A request over the cap
  gets a 503 right away instead of adding to the memory the pod holds.

  Slots are tied to the process that took them. A request that returns,
  raises or exits releases its slot itself; the process is also monitored,
  because when a client hangs up cowboy kills the request process and no
  `after` block runs.

  A slot is held for as long as the response takes. That is bounded by the
  loghub deadline while loghub streams, and by the edge's route timeout
  (30s) for a client that reads slowly: the edge then closes the connection
  and cowboy kills the request process.

  If the limiter itself can't be reached (e.g. while it restarts), callers
  get `{:error, :busy}` too, so the endpoint answers 503 instead of crashing.

  Size: `LOGS_MAX_CONCURRENT` (default 4). A streamed log holds at most about
  one log in memory (1MiB before the response starts, then the batches loghub
  sent ahead of a slow client; archived logs are capped at 16MiB, the read
  cap at 32MiB). The default fits the smallest deployments (a 200Mi pod with
  a ~130Mi baseline, at the typical cost of a few MiB per stream); bigger
  pods should raise it, e.g. 8 for a 640Mi pod. loghub serves 6 streams per
  loghub pod, so a much higher cap here mostly turns into waiting on loghub.

  Metrics: the `in_use` gauge on every change, and a `rejected` counter.
  """

  use GenServer

  alias PipelinesAPI.Util.Metrics

  @default_max_concurrent 4

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Runs `fun` while holding a slot and returns its result, or
  `{:error, :busy}` without running it when every slot is taken.
  """
  def run(server \\ __MODULE__, fun) do
    case acquire(server) do
      :ok ->
        try do
          fun.()
        after
          GenServer.call(server, :release)
        end

      :busy ->
        {:error, :busy}
    end
  end

  defp acquire(server) do
    GenServer.call(server, :acquire)
  catch
    :exit, _reason -> :busy
  end

  def in_use(server \\ __MODULE__), do: GenServer.call(server, :in_use)

  @impl true
  def init(opts) do
    max =
      Keyword.get_lazy(opts, :max_concurrent, fn ->
        Application.get_env(:pipelines_api, :logs_max_concurrent, @default_max_concurrent)
      end)

    {:ok, %{max: max, holders: %{}}}
  end

  @impl true
  def handle_call(:acquire, {pid, _}, state) do
    if map_size(state.holders) < state.max do
      ref = Process.monitor(pid)
      {:reply, :ok, report(put_in(state.holders[ref], pid))}
    else
      Metrics.increment(__MODULE__, ["rejected"])
      {:reply, :busy, state}
    end
  end

  def handle_call(:release, {pid, _}, state) do
    case Enum.find(state.holders, fn {_ref, holder} -> holder == pid end) do
      {ref, _} ->
        Process.demonitor(ref, [:flush])
        {:reply, :ok, report(%{state | holders: Map.delete(state.holders, ref)})}

      nil ->
        {:reply, :ok, state}
    end
  end

  def handle_call(:in_use, _from, state), do: {:reply, map_size(state.holders), state}

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, report(%{state | holders: Map.delete(state.holders, ref)})}
  end

  defp report(state) do
    Watchman.submit({inspect(__MODULE__), ["in_use"]}, map_size(state.holders))
    state
  end
end
