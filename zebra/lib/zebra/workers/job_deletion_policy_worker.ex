defmodule Zebra.Workers.JobDeletionPolicyWorker do
  require Logger

  alias Zebra.Models.Job
  alias Zebra.Models.Project
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

    # sleep_for =
    #   if deleted_any? do
    #     worker.naptime
    #   else
    #     worker.longnaptime || worker.naptime
    #   end

    # Logger.debug("Sleeping for #{sleep_for}ms...")
    # :timer.sleep(sleep_for)
    # Additionally sleeps for 1 minute because we are not deleting anything yet
    :timer.sleep(60_000)

    loop(worker)
  end

  def tick(worker) do
    Logger.info("Starting cleanup tick (limit: #{worker.limit})...")

    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Querying jobs marked for deletion, limit=#{worker.limit}")

    case get_jobs_for_deletion(worker.limit) do
      [] ->
        # DEBUG_LOG
        Logger.debug("DELETION_DEBUG: No jobs found for deletion")
        Logger.info("No expired jobs found for deletion.")
        false

      jobs when is_list(jobs) ->
        # DEBUG_LOG
        Logger.debug(
          "DELETION_DEBUG: Found #{length(jobs)} jobs for deletion, job_ids=#{inspect(Enum.map(jobs, & &1.id))}"
        )

        # DEBUG_LOG
        Logger.debug("DELETION_DEBUG: Publishing deletion messages for #{length(jobs)} jobs")

        case publish_job_deletion_messages(jobs) do
          {:ok, published_job_ids} ->
            # DEBUG_LOG
            Logger.debug(
              "DELETION_DEBUG: Successfully published #{length(published_job_ids)} messages, proceeding with deletion"
            )

            case delete_jobs_and_stop_requests(published_job_ids) do
              {:ok, deleted_stop_requests, deleted_jobs} ->
                total_deleted = deleted_stop_requests + deleted_jobs

                # DEBUG_LOG
                Logger.debug(
                  "DELETION_DEBUG: Deleted #{deleted_stop_requests} stop requests and #{deleted_jobs} jobs"
                )

                Watchman.submit({"retention.deleted", []}, deleted_jobs, :count)

                Logger.info(
                  "Cleanup complete: deleted #{deleted_stop_requests} job stop requests and #{deleted_jobs} jobs (total: #{total_deleted})."
                )

                true

              {:error, reason} ->
                # DEBUG_LOG
                Logger.debug("DELETION_DEBUG: Failed to delete jobs: #{inspect(reason)}")
                Logger.error("Failed to delete jobs after publishing: #{reason}")
                false
            end

          {:error, reason} ->
            # DEBUG_LOG
            Logger.debug("DELETION_DEBUG: Failed to publish messages: #{inspect(reason)}")
            Logger.error("Failed to publish deletion messages: #{reason}")
            false
        end
    end
  end

  defp get_jobs_for_deletion(limit) do
    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Calling Job.get_jobs_marked_for_deletion with limit=#{limit}")

    jobs = Job.get_jobs_marked_for_deletion(limit)

    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Got #{length(jobs)} jobs from database")

    jobs
  end

  defp delete_jobs_and_stop_requests(job_ids) when is_list(job_ids) do
    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Deleting job_stop_requests for #{length(job_ids)} jobs")

    deleted_stop_requests = delete_job_stop_requests(job_ids)

    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Deleted #{deleted_stop_requests} job_stop_requests")

    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Deleting jobs for #{length(job_ids)} job IDs")

    deleted_jobs = delete_jobs(job_ids)

    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Deleted #{deleted_jobs} jobs")

    {:ok, deleted_stop_requests, deleted_jobs}
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  defp delete_job_stop_requests(job_ids) do
    import Ecto.Query, only: [from: 2]

    query =
      from(jsr in Zebra.Models.JobStopRequest,
        where: jsr.job_id in ^job_ids
      )

    {deleted_count, _} = Zebra.LegacyRepo.delete_all(query)
    deleted_count
  end

  defp delete_jobs(job_ids) do
    import Ecto.Query, only: [from: 2]

    query =
      from(j in Zebra.Models.Job,
        where: j.id in ^job_ids
      )

    {deleted_count, _} = Zebra.LegacyRepo.delete_all(query)
    deleted_count
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

  defp publish_job_deletion_messages([]) do
    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: publish_job_deletion_messages called with empty list")
    {:ok, []}
  end

  defp publish_job_deletion_messages(jobs) when is_list(jobs) do
    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Publishing messages for #{length(jobs)} jobs")

    results =
      Enum.map(jobs, fn job ->
        # DEBUG_LOG
        Logger.debug("DELETION_DEBUG: Publishing message for job_id=#{job.id}")

        case publish_job_deletion_message(job) do
          :ok ->
            # DEBUG_LOG
            Logger.debug("DELETION_DEBUG: Successfully published message for job_id=#{job.id}")
            {:ok, job.id}

          {:error, reason} ->
            # DEBUG_LOG
            Logger.debug(
              "DELETION_DEBUG: Failed to publish message for job_id=#{job.id}, reason=#{inspect(reason)}"
            )

            Logger.error(
              "Failed to publish job deletion message for job_id: #{job.id}, reason: #{inspect(reason)}"
            )

            {:error, job.id, reason}
        end
      end)

    # Separate successful and failed publishes
    successful_job_ids =
      results
      |> Enum.filter(fn
        {:ok, _job_id} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, job_id} -> job_id end)

    failed_results =
      results
      |> Enum.filter(fn
        {:error, _job_id, _reason} -> true
        _ -> false
      end)

    # DEBUG_LOG
    Logger.debug(
      "DELETION_DEBUG: Publishing complete - #{length(successful_job_ids)} successful, #{length(failed_results)} failed"
    )

    if length(failed_results) > 0 do
      Logger.warning(
        "Some job deletion messages failed to publish: #{length(failed_results)} out of #{length(jobs)}"
      )
    end

    # Return successfully published job IDs even if some failed
    {:ok, successful_job_ids}
  end

  defp publish_job_deletion_message(job) do
    exchange_name = "artifacthub.job_deletion"
    routing_key = "job.deleted"

    # DEBUG_LOG
    Logger.debug("DELETION_DEBUG: Looking up project for job_id=#{job.id}, project_id=#{job.project_id}")

    case Project.find(job.project_id) do
      {:ok, project} ->
        # DEBUG_LOG
        Logger.debug("DELETION_DEBUG: Found project, artifact_id=#{project.artifact_store_id}")

        message =
          Poison.encode!(%{
            job_id: job.id,
            organization_id: job.organization_id,
            project_id: job.project_id,
            artifact_id: project.artifact_store_id
          })

        # DEBUG_LOG
        Logger.debug("DELETION_DEBUG: Publishing message to RabbitMQ: #{message}")

        try do
          {:ok, channel} = AMQP.Application.get_channel(:job_deletion)
          Tackle.Exchange.create(channel, exchange_name)
          :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

          # DEBUG_LOG
          Logger.debug("DELETION_DEBUG: Successfully published message for job_id=#{job.id}")
          :ok
        rescue
          e ->
            # DEBUG_LOG
            Logger.debug("DELETION_DEBUG: Failed to publish message, error=#{Exception.message(e)}")
            {:error, Exception.message(e)}
        end

      {:error, reason} ->
        # DEBUG_LOG
        Logger.debug("DELETION_DEBUG: Project not found for job_id=#{job.id}, reason=#{inspect(reason)}")

        Logger.error(
          "Failed to find project for job_id: #{job.id}, reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
