defmodule Zebra.Apis.InternalTaskApi.Serializer do
  require Logger

  alias Zebra.LegacyRepo, as: Repo
  alias Zebra.Models.Job

  @job_fields [
    :id,
    :build_id,
    :aasm_state,
    :result,
    :name,
    :index,
    :priority,
    :original_job_id,
    :created_at,
    :enqueued_at,
    :scheduled_at,
    :started_at,
    :finished_at
  ]

  @spec serialize(Zebra.Models.Task.t()) :: InternalApi.Task.Task.t()
  def serialize(task) do
    serialize(task, load_jobs([task.id]))
  end

  defp serialize(task, jobs_by_task) do
    jobs = Map.get(jobs_by_task, task.id, [])

    [
      id: task.id,
      state: serialize_task_state(task),
      result: serialize_task_result(task),
      jobs: Enum.map(jobs, fn j -> serialize_job(j) end),
      ppl_id: task.ppl_id,
      wf_id: task.workflow_id,
      request_token: task.build_request_id
    ]
    |> Keyword.merge(
      Zebra.Apis.Utils.encode_timestamps(
        created_at: task.created_at,
        finished_at: task_finished_at(task)
      )
    )
    |> Zebra.Apis.Utils.remove_nils_from_keywordlist()
    |> InternalApi.Task.Task.new()
  end

  # One query for the jobs of all given tasks, grouped by task id.
  defp load_jobs([]), do: %{}

  defp load_jobs(task_ids) do
    import Ecto.Query

    Job
    |> where([j], j.build_id in ^task_ids)
    |> select([j], struct(j, @job_fields))
    |> Repo.all()
    |> Enum.group_by(& &1.build_id)
  end

  def task_finished_at(task) do
    if Zebra.Models.Task.finished?(task) do
      task.updated_at
    else
      nil
    end
  end

  @spec serialize_many([Zebra.Models.Task.t()]) :: [InternalApi.Task.Task.t()]
  def serialize_many(tasks) do
    jobs_by_task = tasks |> Enum.map(& &1.id) |> Enum.uniq() |> load_jobs()

    Enum.map(tasks, fn t -> serialize(t, jobs_by_task) end)
  end

  @spec serialize_job(Zebra.Models.Job.t()) :: InternalApi.Task.Task.Job.t()
  def serialize_job(job) do
    [
      id: job.id,
      state: serialize_job_state(job),
      result: serialize_job_result(job),
      name: job.name,
      index: job.index,
      priority: job.priority || 50,
      original_job_id: job.original_job_id
    ]
    |> Keyword.merge(
      Zebra.Apis.Utils.encode_timestamps(
        created_at: job.created_at,
        enqueued_at: job.enqueued_at,
        scheduled_at: job.scheduled_at,
        started_at: job.started_at,
        finished_at: job.finished_at
      )
    )
    |> Zebra.Apis.Utils.remove_nils_from_keywordlist()
    |> InternalApi.Task.Task.Job.new()
  end

  @spec serialize_task_state(Zebra.Models.Task.t()) :: InternalApi.Task.Task.State.t()
  def serialize_task_state(task) do
    alias InternalApi.Task.Task.State

    if is_nil(task.result) do
      State.value(:RUNNING)
    else
      State.value(:FINISHED)
    end
  end

  @spec serialize_task_result(Zebra.Models.Task.t()) :: InternalApi.Task.Task.Result.t()
  def serialize_task_result(task) do
    alias InternalApi.Task.Task.Result

    case task.result do
      "passed" -> Result.value(:PASSED)
      "failed" -> Result.value(:FAILED)
      "stopped" -> Result.value(:STOPPED)
      nil -> nil
    end
  end

  @spec serialize_job_state(Zebra.Models.Job.t()) :: InternalApi.Task.Task.Job.State.t()
  def serialize_job_state(job) do
    alias InternalApi.Task.Task.Job.State

    case job.aasm_state do
      "pending" -> State.value(:ENQUEUED)
      "enqueued" -> State.value(:ENQUEUED)
      "scheduled" -> State.value(:ENQUEUED)
      "waiting-for-agent" -> State.value(:ENQUEUED)
      "started" -> State.value(:RUNNING)
      "finished" -> State.value(:FINISHED)
    end
  end

  @spec serialize_job_result(Zebra.Models.Job.t()) :: InternalApi.Task.Task.Job.Result.t()
  def serialize_job_result(job) do
    alias InternalApi.Task.Task.Job.Result

    case job.result do
      "passed" -> Result.value(:PASSED)
      "failed" -> Result.value(:FAILED)
      "stopped" -> Result.value(:STOPPED)
      nil -> nil
    end
  end
end
