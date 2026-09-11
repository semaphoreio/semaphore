defmodule Audit.Retention.Deleter do
  @moduledoc """
  Periodic worker that deletes audit events whose `expires_at` has passed.

  Uses an adaptive cadence (mirroring Zebra's `JobDeletionPolicyWorker`): when a
  tick deletes a full batch there is likely more to clear, so the next tick is
  scheduled after the short `drain` interval; once a tick deletes less than a
  full batch the table is drained and the worker falls back to the longer `idle`
  interval. This lets it clear a backlog (e.g. the initial 400-day sweep)
  instead of being capped at `batch_size / idle_interval` rows per second.

  ## Configuration

  Via application config (typically set from env vars in runtime.exs):

      config :audit, Audit.Retention.Deleter,
        enabled: true,
        batch_size: 100,
        sleep_period_sec: 30,
        drain_period_sec: 1

  ## Environment Variables

  - `RETENTION_DELETER_ENABLED` - "true" to enable (default: "false")
  - `RETENTION_DELETER_BATCH_SIZE` - max events per tick (default: "100")
  - `RETENTION_DELETER_SLEEP_PERIOD_SEC` - idle interval, seconds between ticks
    when nothing is left to delete (default: "30")
  - `RETENTION_DELETER_DRAIN_PERIOD_SEC` - drain interval, seconds between ticks
    while a backlog is being cleared (default: "1")
  """

  use GenServer

  require Logger

  alias Audit.Retention.Queries

  @default_batch_size 100
  @default_idle_period_sec 30
  @default_drain_period_sec 1
  @min_batch_size 1
  @min_period_sec 1
  @backlog_submission_every_ticks 20

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    config = load_config()

    Logger.info(
      "[Retention] Deleter started batch_size=#{config.batch_size} idle_ms=#{config.idle_interval_ms} drain_ms=#{config.drain_interval_ms}"
    )

    schedule(config.idle_interval_ms)
    {:ok, config}
  end

  @impl true
  def handle_info(:tick, state) do
    deleted = delete_batch(state.batch_size)
    state = maybe_submit_backlog(state)
    schedule(next_interval(deleted, state))
    {:noreply, state}
  end

  # A full batch means the table likely still holds expired rows, so keep
  # draining quickly; anything less means we have caught up for now.
  defp next_interval(deleted, state) do
    if deleted >= state.batch_size do
      state.drain_interval_ms
    else
      state.idle_interval_ms
    end
  end

  defp delete_batch(batch_size) do
    case Queries.delete_expired_batch(batch_size) do
      {:ok, 0} ->
        0

      {:ok, count} ->
        Watchman.submit({"retention.deleted", []}, count, :count)
        Logger.info("[Retention] deleted=#{count}")
        count

      {:error, reason} ->
        Watchman.increment("retention.delete.error")
        Logger.error("[Retention] delete error: #{inspect(reason)}")
        0
    end
  end

  defp maybe_submit_backlog(state) do
    tick = state.backlog_tick + 1

    if rem(tick, @backlog_submission_every_ticks) == 0 do
      submit_backlog()
      %{state | backlog_tick: 0}
    else
      %{state | backlog_tick: tick}
    end
  end

  defp submit_backlog do
    case Queries.expired_count() do
      {:ok, count, capped?} ->
        Watchman.submit("retention.backlog", count, :gauge)
        if capped?, do: Watchman.increment("retention.backlog.cap_hit")

      {:error, reason} ->
        Watchman.increment("retention.backlog.error")
        Logger.error("[Retention] backlog metric query failed: #{inspect(reason)}")
    end
  end

  defp schedule(interval_ms) do
    Process.send_after(self(), :tick, interval_ms)
  end

  defp load_config do
    app_config = Application.get_env(:audit, __MODULE__, [])

    batch_size =
      validate_positive_integer(app_config, :batch_size, @default_batch_size, @min_batch_size)

    idle_sec =
      validate_positive_integer(
        app_config,
        :sleep_period_sec,
        @default_idle_period_sec,
        @min_period_sec
      )

    drain_sec =
      validate_positive_integer(
        app_config,
        :drain_period_sec,
        @default_drain_period_sec,
        @min_period_sec
      )

    %{
      batch_size: batch_size,
      idle_interval_ms: idle_sec * 1000,
      drain_interval_ms: drain_sec * 1000,
      backlog_tick: @backlog_submission_every_ticks - 1
    }
  end

  defp validate_positive_integer(config, key, default, min_value) do
    value = Keyword.get(config, key, default)

    if is_integer(value) and value >= min_value do
      value
    else
      Logger.warning(
        "[Retention] invalid #{key}=#{inspect(value)} for #{inspect(__MODULE__)}, using #{default}"
      )

      default
    end
  end
end
