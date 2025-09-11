defmodule Scheduler.Tasks.ReferenceMigration do
  @moduledoc """
  Mix task to manually run the reference field migration.
  
  Usage:
    mix reference_migration.run
    
  Environment variables:
    BATCH_SIZE - Number of records to process per batch (default: 100)
    SLEEP_MS - Milliseconds to sleep between batches (default: 1000)
  """

  require Logger
  
  alias Scheduler.PeriodicsRepo
  alias Scheduler.Periodics.Model.Periodics  
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
  
  import Ecto.Query

  def run do
    Logger.info("Starting reference field migration")
    
    batch_size = System.get_env("BATCH_SIZE", "100") |> String.to_integer()
    sleep_ms = System.get_env("SLEEP_MS", "1000") |> String.to_integer()
    
    migrate_all_periodics(batch_size, sleep_ms)
    migrate_all_triggers(batch_size, sleep_ms)
    
    Logger.info("Migration completed")
  end

  def migrate_all_periodics(batch_size \\ 100, sleep_ms \\ 1000) do
    Logger.info("Migrating periodics table")
    
    total_query = from p in Periodics,
      where: is_nil(p.reference_type) and not is_nil(p.branch),
      select: count()
    
    total_count = PeriodicsRepo.one(total_query)
    Logger.info("Found #{total_count} periodics records to migrate")
    
    migrate_periodics_batches(batch_size, sleep_ms, 0, total_count)
  end

  def migrate_all_triggers(batch_size \\ 100, sleep_ms \\ 1000) do
    Logger.info("Migrating periodics_triggers table")
    
    total_query = from t in PeriodicsTriggers,
      where: is_nil(t.reference_type) and not is_nil(t.branch),
      select: count()
    
    total_count = PeriodicsRepo.one(total_query)
    Logger.info("Found #{total_count} trigger records to migrate")
    
    migrate_triggers_batches(batch_size, sleep_ms, 0, total_count)
  end

  defp migrate_periodics_batches(batch_size, sleep_ms, processed, total) do
    query = from p in Periodics,
      where: is_nil(p.reference_type) and not is_nil(p.branch),
      limit: ^batch_size

    case PeriodicsRepo.all(query) do
      [] ->
        Logger.info("Periodics migration completed. Processed #{processed}/#{total} records")

      records ->
        batch_count = length(records)
        Logger.info("Processing periodics batch: #{processed + batch_count}/#{total}")
        
        {success_count, error_count} = process_periodics_batch(records)
        
        Logger.info("Batch completed - Success: #{success_count}, Errors: #{error_count}")
        
        if sleep_ms > 0, do: Process.sleep(sleep_ms)
        migrate_periodics_batches(batch_size, sleep_ms, processed + batch_count, total)
    end
  end

  defp migrate_triggers_batches(batch_size, sleep_ms, processed, total) do
    query = from t in PeriodicsTriggers,
      where: is_nil(t.reference_type) and not is_nil(t.branch),
      limit: ^batch_size

    case PeriodicsRepo.all(query) do
      [] ->
        Logger.info("Triggers migration completed. Processed #{processed}/#{total} records")

      records ->
        batch_count = length(records)
        Logger.info("Processing triggers batch: #{processed + batch_count}/#{total}")
        
        {success_count, error_count} = process_triggers_batch(records)
        
        Logger.info("Batch completed - Success: #{success_count}, Errors: #{error_count}")
        
        if sleep_ms > 0, do: Process.sleep(sleep_ms)
        migrate_triggers_batches(batch_size, sleep_ms, processed + batch_count, total)
    end
  end

  defp process_periodics_batch(records) do
    Enum.reduce(records, {0, 0}, fn record, {success, error} ->
      changeset = Periodics.changeset_update(record, "v1.1", %{
        reference_type: "branch",
        reference_value: record.branch
      })
      
      case PeriodicsRepo.update(changeset) do
        {:ok, _} -> {success + 1, error}
        {:error, changeset_error} ->
          Logger.error("Failed to migrate periodic #{record.id}: #{inspect(changeset_error.errors)}")
          {success, error + 1}
      end
    end)
  end

  defp process_triggers_batch(records) do
    Enum.reduce(records, {0, 0}, fn record, {success, error} ->
      changeset = PeriodicsTriggers.changeset_update(record, %{
        reference_type: "branch", 
        reference_value: record.branch
      })
      
      case PeriodicsRepo.update(changeset) do
        {:ok, _} -> {success + 1, error}
        {:error, changeset_error} ->
          Logger.error("Failed to migrate trigger #{record.id}: #{inspect(changeset_error.errors)}")
          {success, error + 1}
      end
    end)
  end

  def status do
    periodics_query = from p in Periodics,
      where: is_nil(p.reference_type) and not is_nil(p.branch),
      select: count()
    
    triggers_query = from t in PeriodicsTriggers,
      where: is_nil(t.reference_type) and not is_nil(t.branch),
      select: count()
    
    periodics_remaining = PeriodicsRepo.one(periodics_query)
    triggers_remaining = PeriodicsRepo.one(triggers_query)
    
    %{
      periodics_remaining: periodics_remaining,
      triggers_remaining: triggers_remaining,
      total_remaining: periodics_remaining + triggers_remaining
    }
  end
end