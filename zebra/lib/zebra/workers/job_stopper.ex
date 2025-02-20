defmodule Zebra.Workers.JobStopper do
  require Logger

  alias Zebra.Models.JobStopRequest
  alias Zebra.Models.Job
  alias Zebra.LegacyRepo, as: Repo
  import Ecto.Query

  #
  # Enqueing stop requests.
  #
  def request_stop_async(job) do
    case Zebra.Models.JobStopRequest.find_by_job_id(job.id) do
      {:ok, req} ->
        {:ok, req}

      _ ->
        Zebra.Models.JobStopRequest.create(job.build_id, job.id)
    end
  end

  def request_stop_for_all_jobs_in_task_async(task) do
    task_job_tuples =
      Repo.preload(task, [:jobs]).jobs
      |> Enum.map(fn j ->
        {task.id, j.id}
      end)

    {:ok, _} = Zebra.Models.JobStopRequest.bulk_create(task_job_tuples)

    :ok
  end

  #
  # Processing stop requests.
  #
  def init do
    %Zebra.Workers.DbWorker{
      schema: Zebra.Models.JobStopRequest,
      state_field: :state,
      state_value: Zebra.Models.JobStopRequest.state_pending(),
      metric_name: "job_stopper",
      naptime: 1000,
      processor: &process/1
    }
  end

  def start_link do
    init() |> Zebra.Workers.DbWorker.start_link()
  end

  def process(req) do
    job = load_job_with_lock(req.job_id)

    if job do
      # credo:disable-for-next-line
      cond do
        Job.finished?(job) ->
          {:ok, _} =
            JobStopRequest.complete(
              req,
              JobStopRequest.result_failure(),
              JobStopRequest.result_reason_job_already_finished()
            )

        true ->
          {:ok, _} = Job.stop(job)

          {:ok, _} =
            JobStopRequest.complete(
              req,
              JobStopRequest.result_success(),
              JobStopRequest.result_reason_job_transitioned_to_stopping()
            )
      end
    end
  end

  def load_job_with_lock(job_id) do
    Job
    |> where([j], j.id == ^job_id)
    |> lock("FOR UPDATE SKIP LOCKED")
    |> Repo.one()
  end
end
