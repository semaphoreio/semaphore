defmodule Zebra.Workers.JobDeletionPolicyWorker do
  require Logger

  @self_hosted_prefix "s1-%"

  defstruct [
    # period of sleep between worker ticks
    :naptime,
    # limit for deletions per batch
    :limit,
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

    :timer.sleep(worker.naptime)

    # Recursively call loop to continue periodic execution
    loop(worker)
  end

  def tick(worker) do
    Logger.info("Starting cleanup tick...")

    limit = worker.limit

    Zebra.Models.Job.delete_old_job_stop_requests(limit)
    Zebra.Models.Job.delete_old_jobs(limit)

    Logger.info("Cleanup tick completed.")
  end
end
