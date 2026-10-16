defmodule Zebra.QueueStats do
  @moduledoc """
  Snapshot of scheduled jobs waiting for an agent, per machine type and OS image.

  Machine types are reported after machine translation, so they match what the
  agent provider is asked for.

  The snapshot is refreshed lazily: `get/1` always answers from the last snapshot
  and, when it is older than the refresh interval, starts one background refresh.
  At most one refresh runs at a time and it is killed after a timeout, so callers
  never wait on the database. The query runs with a statement timeout.
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias Zebra.Machines.Translation
  alias Zebra.Models.Job

  @refresh_after_ms 1_000
  @refresh_timeout_ms 3_000
  @statement_timeout_ms 500
  @self_hosted_prefix "s1-"

  defmodule Queue do
    @moduledoc false
    defstruct machine_type: "",
              os_image: "",
              waiting: 0,
              oldest_scheduled_at: nil,
              waiting_orgs: 0,
              self_hosted: false
  end

  defmodule Snapshot do
    @moduledoc false
    defstruct queues: [], generated_at: nil, computed_at_ms: 0
  end

  def start_link(opts \\ []) do
    case Keyword.get(opts, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc """
  Returns `{:ok, snapshot, age_ms}` or `{:error, :not_ready}` when no snapshot exists yet.
  """
  def get(server \\ __MODULE__) do
    GenServer.call(server, :get)
  catch
    :exit, _ -> {:error, :not_ready}
  end

  @doc """
  Computes a snapshot in the caller's process, stores it and returns it.
  """
  def refresh_sync(server \\ __MODULE__) do
    GenServer.call(server, :refresh_sync, @refresh_timeout_ms + 1_000)
  end

  @doc """
  Filters a snapshot's queues by environment: `:ALL`, `:CLOUD` or `:SELF_HOSTED`.
  """
  def filter(queues, :CLOUD), do: Enum.reject(queues, & &1.self_hosted)
  def filter(queues, :SELF_HOSTED), do: Enum.filter(queues, & &1.self_hosted)
  def filter(queues, _), do: queues

  @doc """
  Seconds between `now` and the queue's oldest scheduled job.
  """
  def oldest_wait_seconds(%Queue{oldest_scheduled_at: nil}, _now), do: 0

  def oldest_wait_seconds(%Queue{oldest_scheduled_at: at}, now) do
    max(DateTime.diff(now, at, :second), 0)
  end

  #
  # Computation
  #

  @doc """
  Reads waiting jobs and aggregates them. Returns `{:ok, queues}` or `{:error, reason}`.
  """
  def compute do
    result =
      Zebra.LegacyRepo.transaction(fn ->
        Zebra.LegacyRepo.query!("SET LOCAL statement_timeout = #{@statement_timeout_ms}")
        Zebra.LegacyRepo.all(waiting_query())
      end)

    case result do
      {:ok, rows} -> {:ok, aggregate(rows)}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, e}
  end

  defp waiting_query do
    from(j in Job,
      where: j.aasm_state == ^Job.state_scheduled(),
      group_by: [j.machine_type, j.machine_os_image, j.organization_id],
      select:
        {j.machine_type, j.machine_os_image, j.organization_id, count(j.id), min(j.scheduled_at)}
    )
  end

  @doc false
  def aggregate(rows) do
    rows
    |> Enum.reduce(%{}, fn {machine_type, os_image, org_id, count, oldest}, acc ->
      {type, image} = translate(machine_type, os_image, org_id)

      Map.update(
        acc,
        {type, image},
        %{waiting: count, oldest: oldest, orgs: MapSet.new([org_id])},
        fn q ->
          %{
            waiting: q.waiting + count,
            oldest: earliest(q.oldest, oldest),
            orgs: MapSet.put(q.orgs, org_id)
          }
        end
      )
    end)
    |> Enum.map(fn {{type, image}, q} ->
      %Queue{
        machine_type: type,
        os_image: image,
        waiting: q.waiting,
        oldest_scheduled_at: q.oldest,
        waiting_orgs: MapSet.size(q.orgs),
        self_hosted: String.starts_with?(type, @self_hosted_prefix)
      }
    end)
    |> Enum.sort_by(&{&1.machine_type, &1.os_image})
  end

  defp translate(machine_type, os_image, org_id) do
    if Translation.translatable?(machine_type) do
      {type, image, _} = Translation.translate(machine_type, os_image, org_id)
      {type, image}
    else
      {machine_type || "", os_image || ""}
    end
  rescue
    e ->
      Logger.warning("Queue stats: machine translation failed: #{inspect(e)}")
      Watchman.increment("queue_stats.translation_error")
      {machine_type || "", os_image || ""}
  end

  defp earliest(nil, b), do: b
  defp earliest(a, nil), do: a
  defp earliest(a, b), do: if(DateTime.compare(a, b) == :gt, do: b, else: a)

  #
  # Server
  #

  @impl true
  def init(opts) do
    {:ok, task_sup} = Task.Supervisor.start_link()

    {:ok,
     %{
       snapshot: nil,
       task: nil,
       task_sup: task_sup,
       compute: Keyword.get(opts, :compute, &__MODULE__.compute/0),
       refresh_after_ms: Keyword.get(opts, :refresh_after_ms, @refresh_after_ms),
       refresh_timeout_ms: Keyword.get(opts, :refresh_timeout_ms, @refresh_timeout_ms)
     }}
  end

  @impl true
  def handle_call(:get, _from, state) do
    state = maybe_refresh(state)
    {:reply, reply(state.snapshot), state}
  end

  def handle_call(:refresh_sync, _from, state) do
    state = store(state, state.compute.())
    {:reply, reply(state.snapshot), state}
  end

  @impl true
  def handle_info({ref, result}, state = %{task: %Task{ref: ref}}) do
    Process.demonitor(ref, [:flush])
    {:noreply, store(%{state | task: nil}, result)}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, state = %{task: %Task{ref: ref}}) do
    Logger.error("Queue stats refresh crashed: #{inspect(reason)}")
    Watchman.increment("queue_stats.refresh_error")
    {:noreply, %{state | task: nil}}
  end

  def handle_info({:refresh_timeout, ref}, state = %{task: task = %Task{ref: ref}}) do
    Task.shutdown(task, :brutal_kill)
    Logger.error("Queue stats refresh timed out")
    Watchman.increment("queue_stats.refresh_timeout")
    {:noreply, %{state | task: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp maybe_refresh(state = %{task: nil}) do
    if stale?(state) do
      task = Task.Supervisor.async_nolink(state.task_sup, state.compute)
      Process.send_after(self(), {:refresh_timeout, task.ref}, state.refresh_timeout_ms)
      %{state | task: task}
    else
      state
    end
  end

  defp maybe_refresh(state), do: state

  defp stale?(%{snapshot: nil}), do: true

  defp stale?(state) do
    now_ms() - state.snapshot.computed_at_ms >= state.refresh_after_ms
  end

  defp store(state, {:ok, queues}) do
    Watchman.increment("queue_stats.refresh")

    snapshot = %Snapshot{
      queues: queues,
      generated_at: DateTime.utc_now(),
      computed_at_ms: now_ms()
    }

    %{state | snapshot: snapshot}
  end

  defp store(state, {:error, reason}) do
    Logger.error("Queue stats refresh failed: #{inspect(reason)}")
    Watchman.increment("queue_stats.refresh_error")
    state
  end

  defp reply(nil), do: {:error, :not_ready}
  defp reply(snapshot), do: {:ok, snapshot, now_ms() - snapshot.computed_at_ms}

  defp now_ms, do: System.monotonic_time(:millisecond)
end
