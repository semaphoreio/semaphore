defmodule RepositoryHub.BuildStatusGuardCleanupWorker do
  @moduledoc """
  Periodically deletes build_status_guards rows that were not touched for
  seven days. Statuses only matter for hours, so expired rows are dead
  weight. Deletes are idempotent, so running on every instance is safe.
  """

  use GenServer

  require Logger

  alias RepositoryHub.Repo

  @tick_interval :timer.hours(1)
  @retention_days 7
  @batch_size 5_000

  @delete_sql """
  DELETE FROM build_status_guards
  WHERE ctid IN (
    SELECT ctid FROM build_status_guards
    WHERE updated_at < now() - interval '#{@retention_days} days'
    LIMIT #{@batch_size}
  )
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_tick()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    cleanup()
    schedule_tick()
    {:noreply, state}
  end

  defp cleanup do
    case Repo.query(@delete_sql, [], timeout: 30_000) do
      {:ok, %{num_rows: num_rows}} when num_rows > 0 ->
        Logger.info("[BuildStatusGuardCleanupWorker] deleted #{num_rows} expired rows")
        if num_rows == @batch_size, do: send(self(), :tick)

      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.warning("[BuildStatusGuardCleanupWorker] cleanup failed: #{inspect(error)}")
    end
  rescue
    error ->
      Logger.warning("[BuildStatusGuardCleanupWorker] cleanup failed: #{inspect(error)}")
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
