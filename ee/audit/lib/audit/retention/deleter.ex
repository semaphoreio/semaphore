defmodule Audit.Retention.Deleter do
  @moduledoc """
  Periodic worker that deletes audit events whose `expires_at` has passed.

  ## Configuration

  Via application config (typically set from env vars in runtime.exs):

      config :audit, Audit.Retention.Deleter,
        enabled: true,
        batch_size: 100,
        sleep_period_sec: 30

  ## Environment Variables

  - `RETENTION_DELETER_ENABLED` - "true" to enable (default: "false")
  - `RETENTION_DELETER_BATCH_SIZE` - max events per tick (default: "100")
  - `RETENTION_DELETER_SLEEP_PERIOD_SEC` - seconds between ticks (default: "30")
  """

  use GenServer

  require Logger

  alias Audit.Retention.Queries

  @default_batch_size 100
  @default_interval_ms 30_000
  @min_batch_size 1
  @min_sleep_period_sec 1
  @backlog_submission_every_ticks 20

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    config = load_config()

    Logger.info(
      "[Retention] Deleter started batch_size=#{config.batch_size} interval_ms=#{config.interval_ms}"
    )

    schedule(config.interval_ms)
    {:ok, config}
  end

  @impl true
  def handle_info(:tick, state) do
    delete_batch(state.batch_size)
    state = maybe_submit_backlog(state)
    schedule(state.interval_ms)
    {:noreply, state}
  end

  defp delete_batch(batch_size) do
    case Queries.delete_expired_batch(batch_size) do
      {:ok, 0} ->
        :ok

      {:ok, count} ->
        Watchman.submit({"retention.deleted", []}, count, :count)
        Logger.info("[Retention] deleted=#{count}")

      {:error, reason} ->
        Watchman.increment("retention.delete.error")
        Logger.error("[Retention] delete error: #{inspect(reason)}")
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

    sleep_period_sec =
      validate_positive_integer(app_config, :sleep_period_sec, @min_sleep_period_sec)

    batch_size = validate_positive_integer(app_config, :batch_size, @min_batch_size)

    %{
      batch_size: batch_size,
      interval_ms: sleep_period_sec * 1000,
      backlog_tick: @backlog_submission_every_ticks - 1
    }
  end

  defp validate_positive_integer(config, key, min_value) do
    default =
      case key do
        :batch_size -> @default_batch_size
        :sleep_period_sec -> div(@default_interval_ms, 1000)
      end

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
