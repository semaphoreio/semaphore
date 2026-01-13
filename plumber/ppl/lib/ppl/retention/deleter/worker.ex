defmodule Ppl.Retention.Deleter.Worker do
  @moduledoc """
  Periodic worker that deletes expired pipeline records.

  ## Configuration

  Via application config:
    config :ppl, Ppl.Retention.Deleter.Worker,
      sleep_period_sec: 30,
      batch_size: 100

  ## Runtime Control

  - `pause/0` - pause deletions indefinitely
  - `pause_for/1` - pause for N milliseconds
  - `resume/0` - resume deletions
  - `status/0` - returns `:running` or `:paused`
  - `config/0` - returns current configuration
  - `update_config/1` - updates interval_ms and/or batch_size
  """

  use GenServer

  require Logger

  alias Ppl.Retention.Deleter.Queries
  alias Ppl.Retention.Deleter.State
  alias Ppl.Retention.StateAgent

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def pause do
    StateAgent.update_state(__MODULE__, &State.pause/1)
    Logger.info("[Retention] Deleter paused")
    :ok
  end

  def pause_for(ms) when is_integer(ms) and ms > 0 do
    StateAgent.update_state(__MODULE__, &State.pause_for(&1, ms))
    Logger.info("[Retention] Deleter paused for #{ms}ms")
    :ok
  end

  def resume do
    StateAgent.update_state(__MODULE__, &State.resume/1)
    Logger.info("[Retention] Deleter resumed")
    :ok
  end

  def status do
    case State.check_pause(StateAgent.get_state(__MODULE__)) do
      {:running, _} -> :running
      {:paused, _} -> :paused
    end
  end

  def paused? do
    case State.check_pause(StateAgent.get_state(__MODULE__)) do
      {:running, _} -> false
      {:paused, _} -> true
    end
  end

  def config, do: State.to_config(StateAgent.get_state(__MODULE__))

  def update_config(opts) do
    new_state = StateAgent.update_state(__MODULE__, &State.update(&1, opts))
    Logger.info("[Retention] Deleter config updated interval=#{new_state.interval_ms}ms batch=#{new_state.batch_size}")
    :ok
  end

  @impl true
  def init([]) do
    state = StateAgent.get_state(__MODULE__)
    Logger.info("[Retention] Deleter started interval=#{state.interval_ms}ms batch=#{state.batch_size}")
    schedule(state.interval_ms)
    {:ok, nil}
  end

  @impl true
  def handle_info(:tick, _genserver_state) do
    run_if_not_paused()
    state = StateAgent.get_state(__MODULE__)
    schedule(state.interval_ms)
    {:noreply, nil}
  end

  defp run_if_not_paused do
    state = StateAgent.get_state(__MODULE__)

    case State.check_pause(state) do
      {:paused, _} ->
        :ok

      {:running, new_state} ->
        StateAgent.put_state(__MODULE__, new_state)
        delete_batch(new_state.batch_size)
    end
  end

  defp delete_batch(batch_size) do
    case Queries.delete_expired_batch(batch_size) do
      {:ok, 0} -> :ok
      {:ok, count} ->
        Watchman.submit({"retention.deleted", []}, count, :count)
        Logger.info("[Retention] deleted=#{count}")
      {:error, reason} ->
        Logger.error("[Retention] delete error: #{inspect(reason)}")
    end
  end

  defp schedule(interval_ms) do
    Process.send_after(self(), :tick, interval_ms)
  end
end
