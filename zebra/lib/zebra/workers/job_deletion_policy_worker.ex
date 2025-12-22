defmodule Zebra.Workers.JobDeletionPolicyWorker do
  require Logger

  alias Zebra.Models.Job

  defstruct [
    # period of sleep between worker ticks when jobs are deleted
    :naptime,
    # longer period of sleep when there is nothing to delete
    :longnaptime,
    # limit for deletions per batch
    :limit
  ]

  def start_link do
    with {:ok, worker_config} <- fetch_config(),
         {:ok, worker} <- validate_and_build_worker(worker_config) do
      pid = spawn_link(fn -> loop(worker) end)
      Logger.info("JobDeletionPolicyWorker started with config: #{inspect(worker)}")
      {:ok, pid}
    else
      {:error, reason} ->
        Logger.error("Failed to start JobDeletionPolicyWorker: #{reason}")
        {:error, reason}
    end
  end

  def loop(worker) do
    deleted_any? = tick(worker)

    sleep_for =
      if deleted_any? do
        worker.naptime
      else
        worker.longnaptime || worker.naptime
      end

    Logger.debug("Sleeping for #{sleep_for}ms...")
    :timer.sleep(sleep_for)

    loop(worker)
  end

  def tick(worker) do
    Logger.info("Starting cleanup tick (limit: #{worker.limit})...")

    case delete_expired_data(worker.limit) do
      {:ok, 0, 0} ->
        Logger.info("No expired jobs found for deletion.")
        false

      {:ok, deleted_stop_requests, deleted_jobs} ->
        total_deleted = deleted_stop_requests + deleted_jobs

        Watchman.submit({"retention.deleted"}, deleted_jobs, :count)

        Logger.info(
          "Cleanup complete: deleted #{deleted_stop_requests} job stop requests and #{deleted_jobs} jobs (total: #{total_deleted})."
        )

        true

      {:error, reason} ->
        Logger.error("Cleanup tick failed: #{reason}")
        false
    end
  end

  defp delete_expired_data(limit) do
    with {:ok, jobs_expired} <- Job.expired_job_ids(limit),
         true <- length(jobs_expired) > 0 do
      job_ids = Enum.map(jobs_expired, fn {id, _organization_id, _project_id} -> id end)

      {:ok, _} = Job.publish_job_deletion_events(jobs_expired)

      {:ok, deleted_stop_requests} = Job.delete_job_stop_requests(job_ids)
      {:ok, deleted_jobs} = Job.delete_jobs(job_ids)
      {:ok, deleted_stop_requests, deleted_jobs}
      # {:ok, 0, 0}
    else
      false ->
        {:ok, 0, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_config do
    case Application.fetch_env(:zebra, __MODULE__) do
      {:ok, config} -> {:ok, config}
      :error -> {:error, "Worker configuration is missing"}
    end
  end

  defp validate_and_build_worker(config) do
    with {:ok, naptime} <- validate_naptime(config),
         {:ok, longnaptime} <- validate_longnaptime(config),
         {:ok, limit} <- validate_limit(config) do
      worker = %__MODULE__{
        naptime: naptime,
        longnaptime: longnaptime,
        limit: limit
      }

      {:ok, worker}
    end
  end

  defp validate_naptime(config) do
    case Keyword.fetch(config, :naptime) do
      {:ok, naptime} when is_integer(naptime) and naptime > 0 ->
        {:ok, naptime}

      {:ok, invalid} ->
        {:error, "Invalid naptime: expected positive integer, got #{inspect(invalid)}"}

      :error ->
        {:error, "naptime configuration is missing"}
    end
  end

  defp validate_longnaptime(config) do
    case Keyword.fetch(config, :longnaptime) do
      {:ok, longnaptime} when is_integer(longnaptime) and longnaptime > 0 ->
        {:ok, longnaptime}

      {:ok, nil} ->
        {:ok, nil}

      {:ok, invalid} ->
        {:error, "Invalid longnaptime: expected positive integer or nil, got #{inspect(invalid)}"}

      :error ->
        {:ok, nil}
    end
  end

  defp validate_limit(config) do
    case Keyword.fetch(config, :limit) do
      {:ok, limit} when is_integer(limit) and limit > 0 ->
        {:ok, limit}

      {:ok, invalid} ->
        {:error, "Invalid limit: expected positive integer, got #{inspect(invalid)}"}

      :error ->
        {:error, "limit configuration is missing"}
    end
  end
end
