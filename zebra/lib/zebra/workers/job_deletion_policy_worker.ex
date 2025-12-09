defmodule Zebra.Workers.JobDeletionPolicyWorker do
  require Logger

  alias Zebra.Models.Job
  alias Zebra.JobDeletedPublisher

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
    # Additionally sleeps for 14 seconds because we are not deleting anything yet
    :timer.sleep(14_000)

    loop(worker)
  end

  def tick(worker) do
    Logger.info("Starting cleanup tick (limit: #{worker.limit})...")

    case delete_expired_data(worker.limit) do
      {:ok, 0, 0, []} ->
        Logger.info("No expired jobs found for deletion.")
        false

      {:ok, deleted_stop_requests, deleted_jobs, deleted_jobs_list} ->
        total_deleted = deleted_stop_requests + deleted_jobs

        Watchman.submit({"retention.deleted"}, deleted_jobs, :count)

        Logger.info(
          "Cleanup complete: deleted #{deleted_stop_requests} job stop requests and #{deleted_jobs} jobs (total: #{total_deleted})."
        )

        publish_job_deletion_messages(10)

        true

      {:error, reason} ->
        Logger.error("Cleanup tick failed: #{reason}")
        false
    end
  end

  defp delete_expired_data(limit) do
    # with {:ok, deleted_stop_requests} <- Job.delete_old_job_stop_requests(limit),
    #      {:ok, deleted_jobs, jobs_to_delete} <- Job.delete_old_jobs(limit) do
    #   {:ok, deleted_stop_requests, deleted_jobs, jobs_to_delete}
    # else
    #   {:error, reason} -> {:error, reason}
    #   error -> {:error, "Unexpected error: #{inspect(error)}"}
    # end
    # For now this will return just a list of jobs to simulate deletion
    case Job.get_jobs_marked_for_deletion(limit) do
      {:ok, jobs} ->
        deleted_jobs_count = length(jobs)
        {:ok, 0, deleted_jobs_count, jobs}

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

  defp publish_job_deletion_messages([]), do: :ok

  defp publish_job_deletion_messages(jobs) do
    spawn(fn ->
      Enum.each(jobs, fn job ->
        Logger.debug("Publishing job deletion message for job_id: #{job.id}")

        case publish_job_deletion_message(job) do
          :ok ->
            Logger.debug("Published job deletion message for job_id: #{job.id}")

          {:error, reason} ->
            Logger.error(
              "Failed to publish job deletion message for job_id: #{job.id}, reason: #{inspect(reason)}"
            )
        end
      end)
    end)

    :ok
  end

  defp publish_job_deletion_message(job) do
    exchange_name = "artifacthub.job_deletion"
    routing_key = "job.deleted"

    message =
      Poison.encode!(%{
        job_id: job.id,
        organization_id: job.organization_id,
        project_id: job.project_id
      })

    try do
      {:ok, channel} = AMQP.Application.get_channel(:job_deletion)
      Tackle.Exchange.create(channel, exchange_name)
      :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
      :ok
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
end
