defmodule Ppl.Retention.RecordDeleter do
  @moduledoc """
  Periodic worker that deletes expired pipeline records.

  Runs every 30 seconds (configurable) and deletes records where `expires_at < now`
  in batches.

  Can be disabled via RETENTION_DELETER_ENABLED=false env var.
  """

  use GenServer

  require Logger

  alias Ppl.Retention.RecordDeleterQueries

  @default_sleep_period_sec 30
  @default_batch_size 100

  def start_link(_opts \\ []) do
    if enabled?() do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    else
      Logger.info("[Retention] Deleter disabled via config")
      :ignore
    end
  end

  @impl true
  def init(_) do
    Logger.info("[Retention] Deleter started")
    schedule_next_cycle()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:run_cycle, state) do
    run_deletion_cycle()
    schedule_next_cycle()
    {:noreply, state}
  end

  defp schedule_next_cycle do
    Process.send_after(self(), :run_cycle, sleep_period_sec() * 1000)
  end

  defp run_deletion_cycle do
    case RecordDeleterQueries.delete_expired_batch(batch_size()) do
      {:ok, 0} ->
        :ok

      {:ok, deleted_count} ->
        Watchman.submit({"retention.deleted", []}, deleted_count, :count)
        has_more = deleted_count >= batch_size()
        Logger.info("[Retention] deleted=#{deleted_count} has_more=#{has_more}")

      {:error, reason} ->
        Logger.error("[Retention] Deleter error: #{inspect(reason)}")
    end
  end

  defp sleep_period_sec do
    config = Application.get_env(:ppl, __MODULE__, [])
    Keyword.get(config, :sleep_period_sec, @default_sleep_period_sec)
  end

  defp batch_size do
    config = Application.get_env(:ppl, __MODULE__, [])
    Keyword.get(config, :batch_size, @default_batch_size)
  end

  defp enabled? do
    config = Application.get_env(:ppl, __MODULE__, [])
    Keyword.get(config, :enabled, true)
  end
end
