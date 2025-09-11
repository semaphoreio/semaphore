defmodule Scheduler.Workers.ReferenceMigrationWorker do
  @moduledoc """
  Background worker to migrate old branch-based entries to the new reference model.
  Processes records in batches to avoid overwhelming the database.
  """

  use GenServer
  require Logger

  alias Scheduler.PeriodicsRepo
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
  
  import Ecto.Query

  @batch_size 100
  @sleep_between_batches 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("ReferenceMigrationWorker started")
    send(self(), :migrate_periodics)
    {:ok, %{status: :idle}}
  end

  def handle_info(:migrate_periodics, state) do
    Logger.info("Starting periodics migration")
    migrate_periodics_batch()
    send(self(), :migrate_triggers)
    {:noreply, %{state | status: :migrating_periodics}}
  end

  def handle_info(:migrate_triggers, state) do
    Logger.info("Starting triggers migration")
    migrate_triggers_batch()
    Logger.info("Migration completed")
    {:noreply, %{state | status: :completed}}
  end

  def handle_info(:continue_periodics, state) do
    migrate_periodics_batch()
    {:noreply, state}
  end

  def handle_info(:continue_triggers, state) do
    migrate_triggers_batch()
    {:noreply, state}
  end

  defp migrate_periodics_batch do
    query = from p in Periodics,
      where: is_nil(p.reference_type) and not is_nil(p.branch),
      limit: @batch_size,
      select: [:id, :branch]

    case PeriodicsRepo.all(query) do
      [] ->
        Logger.info("No more periodics records to migrate")

      records ->
        Logger.info("Migrating #{length(records)} periodics records")
        
        Enum.each(records, fn record ->
          changeset = Periodics.changeset(record, "v1.1", %{
            reference_type: "branch",
            reference_value: record.branch
          })
          
          case PeriodicsRepo.update(changeset) do
            {:ok, _} -> :ok
            {:error, changeset} ->
              Logger.error("Failed to migrate periodic #{record.id}: #{inspect(changeset.errors)}")
          end
        end)

        Process.sleep(@sleep_between_batches)
        send(self(), :continue_periodics)
    end
  end

  defp migrate_triggers_batch do
    query = from t in PeriodicsTriggers,
      where: is_nil(t.reference_type) and not is_nil(t.branch),
      limit: @batch_size,
      select: [:id, :branch]

    case PeriodicsRepo.all(query) do
      [] ->
        Logger.info("No more triggers records to migrate")

      records ->
        Logger.info("Migrating #{length(records)} triggers records")
        
        Enum.each(records, fn record ->
          changeset = PeriodicsTriggers.changeset_update(record, %{
            reference_type: "branch",
            reference_value: record.branch
          })
          
          case PeriodicsRepo.update(changeset) do
            {:ok, _} -> :ok
            {:error, changeset} ->
              Logger.error("Failed to migrate trigger #{record.id}: #{inspect(changeset.errors)}")
          end
        end)

        Process.sleep(@sleep_between_batches)
        send(self(), :continue_triggers)
    end
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  def force_migrate do
    GenServer.cast(__MODULE__, :force_migrate)
  end

  def handle_cast(:force_migrate, state) do
    Logger.info("Force migration requested")
    send(self(), :migrate_periodics)
    {:noreply, %{state | status: :migrating_periodics}}
  end
end