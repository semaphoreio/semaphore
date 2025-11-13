defmodule Zebra.Workers.JobDeletionPolicyWorker do
  import Ecto.Query
  require Logger
  alias Zebra.LegacyRepo, as: Repo

  @self_hosted_prefix "s1-%"

  defstruct [
    :naptime, # period of sleep between worker ticks
    :records_per_tick, # how many records to process per tick
    :days, # number of days to consider old jobs
    :limit, # limit for deletions per batch
    :deletion_delay # delay in milliseconds between deletion batches
  ]

  def start_link(worker) do
    pid =
      spawn_link(fn ->
        loop(worker)
      end)

    {:ok, pid}
  end

  def loop(worker) do
    # Perform a tick (cleaning operation)
    Task.async(fn -> tick(worker) end) |> Task.await(:infinity)

    # Sleep for the configured naptime before the next tick
    :timer.sleep(worker.naptime)

    # Recursively call loop to continue periodic execution
    loop(worker)
  end

  def tick(worker) do
    Logger.info("Starting cleanup tick...")

    # Get all organizations with old jobs
    orgs = Zebra.Models.Job.get_organizations_with_jobs()

    Enum.map(orgs, fn org_id ->
      if data_deletion_enabled?(org_id) do
        org_id
      else
        nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.each(fn org_id ->
      Logger.info("Cleaning up jobs for organization #{org_id}")

      delete_stop_requests_until_empty(org_id, worker.days, worker.limit, worker.deletion_delay)
      delete_jobs_until_empty(org_id, worker.days, worker.limit, worker.deletion_delay)
    end)

    Logger.info("Cleanup tick completed.")
  end

  defp delete_stop_requests_until_empty(org_id, days, limit, deletion_delay) do
    Stream.iterate(0, &(&1 + 1))
    |> Enum.reduce_while(0, fn _, _ ->
      case Zebra.Models.Job.delete_old_job_stop_requests(org_id, days, limit) do
        {:ok, 0} -> {:halt, :done}
        {:ok, _deleted_count} ->
          :timer.sleep(deletion_delay)
          {:cont, :continue}
        {:error, reason} ->
          Logger.error("Error deleting job stop requests for org #{org_id}: #{inspect(reason)}")
          {:halt, :error}
      end
    end)
  end

  defp delete_jobs_until_empty(org_id, days, limit, deletion_delay) do
    Stream.iterate(0, &(&1 + 1))
    |> Enum.reduce_while(0, fn _, _ ->
      case Zebra.Models.Job.delete_old_jobs(org_id, days, limit) do
        {:ok, 0} -> {:halt, :done}
        {:ok, _deleted_count} ->
          :timer.sleep(deletion_delay)
          {:cont, :continue}
        {:error, reason} ->
          Logger.error("Error deleting jobs for org #{org_id}: #{inspect(reason)}")
          {:halt, :error}
      end
    end)
  end

  defp data_deletion_enabled?(org_id) do
    FeatureProvider.feature_enabled?("data_deletion_enabled", param: org_id)
  end
end
