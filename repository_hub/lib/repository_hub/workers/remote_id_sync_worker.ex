defmodule RepositoryHub.RemoteIdSyncWorker do
  use GenServer

  require Logger

  alias RepositoryHub.{Adapters, Model, Repo, SyncRepositoryAction, Toolkit}

  @default_rate_limit_per_minute 10

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def pause_for(milliseconds) when is_integer(milliseconds) and milliseconds > 0 do
    GenServer.cast(__MODULE__, {:pause_for, milliseconds})
  end

  def pause do
    GenServer.cast(__MODULE__, :pause)
  end

  def resume do
    GenServer.cast(__MODULE__, :resume)
  end

  def status do
    GenServer.call(__MODULE__, :get_status)
  end

  def paused? do
    GenServer.call(__MODULE__, :paused?)
  end

  @impl true
  def init(opts) do
    rate_limit = Keyword.get(opts, :rate_limit_per_minute, @default_rate_limit_per_minute)

    state = %{
      interval_ms: interval_ms(rate_limit),
      paused_until: :infinity
    }

    schedule_tick(0)
    {:ok, state}
  end

  @impl true
  def handle_cast(:pause, state) do
    Logger.info("[RemoteIdSyncWorker] Paused indefinitely")
    {:noreply, %{state | paused_until: :infinity}}
  end

  def handle_cast({:pause_for, milliseconds}, state) do
    paused_until = System.monotonic_time(:millisecond) + milliseconds
    Logger.info("[RemoteIdSyncWorker] Paused for #{milliseconds}ms")
    {:noreply, %{state | paused_until: paused_until}}
  end

  def handle_cast(:resume, state) do
    Logger.info("[RemoteIdSyncWorker] Resumed")
    {:noreply, %{state | paused_until: nil}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status =
      case paused_state(state) do
        {:paused, _} -> :paused
        {:running, _} -> :running
      end

    {:reply, status, state}
  end

  def handle_call(:paused?, _from, state) do
    is_paused =
      case paused_state(state) do
        {:paused, _} -> true
        {:running, _} -> false
      end

    {:reply, is_paused, state}
  end

  @impl true
  def handle_info(:tick, state) do
    state = maybe_process_next_repository(state)
    schedule_tick(state.interval_ms)
    {:noreply, state}
  end

  defp maybe_process_next_repository(state) do
    case paused_state(state) do
      {:paused, state} ->
        state

      {:running, state} ->
        process_next_repository()
        state
    end
  end

  defp paused_state(%{paused_until: :infinity} = state), do: {:paused, state}

  defp paused_state(%{paused_until: nil} = state), do: {:running, state}

  defp paused_state(%{paused_until: paused_until} = state) do
    now = System.monotonic_time(:millisecond)

    if now >= paused_until do
      {:running, %{state | paused_until: nil}}
    else
      {:paused, state}
    end
  end

  defp process_next_repository do
    Repo.transaction(fn ->
      case Model.RepositoryQuery.lock_next_github_without_remote_id() do
        nil ->
          :noop

        repository ->
          sync_repository(repository)
      end
    end)
    |> case do
      {:ok, :noop} ->
        :ok

      {:ok, result} ->
        result

      {:error, error} ->
        Logger.warning("[RemoteIdSyncWorker] Failed to lock repository: #{inspect(error)}")
    end
  end

  defp sync_repository(repository) do
    {:ok, adapter} = Adapters.from_repository_id(%{repository_id: repository.id})

    SyncRepositoryAction.execute(adapter, repository.id)
    |> Toolkit.unwrap_error(fn error ->
      Logger.warning("[RemoteIdSyncWorker] Sync failed for #{repository.id}: #{inspect(error)}")
    end)
  end

  defp interval_ms(rate_limit) when is_integer(rate_limit) and rate_limit > 0 do
    div(:timer.minutes(1), rate_limit)
  end

  defp interval_ms(_), do: div(:timer.minutes(1), @default_rate_limit_per_minute)

  defp schedule_tick(interval_ms) do
    Process.send_after(self(), :tick, interval_ms)
  end
end
