defmodule Zebra.Workers.JobDeletionPolicyWorker do
  require Logger

  @self_hosted_prefix "s1-%"

  defstruct [
    # period of sleep between worker ticks
    :naptime,
    # longer period of sleep when there is nothing to delete
    :longnaptime,
    # limit for deletions per batch
    :limit
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
    deleted_any? = Task.async(fn -> tick(worker) end) |> Task.await(:infinity)

    sleep_for =
      if deleted_any? do
        worker.naptime
      else
        worker.longnaptime || worker.naptime
      end

    :timer.sleep(sleep_for)

    # Recursively call loop to continue periodic execution
    loop(worker)
  end

  def tick(worker) do
    Logger.info("Starting cleanup tick...")

    limit = worker.limit

    {:ok, deleted_stop_requests} = Zebra.Models.Job.delete_old_job_stop_requests(limit)
    {:ok, deleted_jobs} = Zebra.Models.Job.delete_old_jobs(limit)

    total_deleted = deleted_stop_requests + deleted_jobs

    if total_deleted == 0 do
      Logger.info("No jobs found for deletion.")
      false
    else
      Logger.info("Deleted #{deleted_stop_requests} job stop requests and #{deleted_jobs} jobs.")
      true
    end
  end
end
