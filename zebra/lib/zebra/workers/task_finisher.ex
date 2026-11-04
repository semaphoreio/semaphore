defmodule Zebra.Workers.TaskFinisher do
  alias Zebra.Models.Job
  alias Zebra.LegacyRepo, as: Repo

  import Ecto.Query
  require Logger

  def start_link do
    pid = spawn_link(&loop/0)

    {:ok, pid}
  end

  def config(key) do
    config = Application.get_env(:zebra, __MODULE__)

    Keyword.fetch(config, key)
  end

  def loop do
    {:ok, timeout} = config(:timeout)

    Task.async(fn -> tick() end) |> Task.await(:infinity)
    :timer.sleep(timeout)

    loop()
  end

  def tick do
    task_ids = finishable_task_ids()

    Enum.each(task_ids, fn id -> lock_and_process(id) end)
  end

  def lock_and_process(task_id) do
    Repo.transaction(fn ->
      task =
        Zebra.Models.Task
        |> where([t], is_nil(t.result))
        |> where([t], t.id == ^task_id)
        |> lock("FOR UPDATE SKIP LOCKED")
        |> Repo.one()

      if task do
        process(task)
      end
    end)
  end

  def process(task) do
    Watchman.benchmark("task_finisher.process.duration", fn ->
      # Runs after every job finish. While the task still has unfinished jobs
      # this is a single index probe, so the cost of a finish does not grow
      # with the number of jobs in the task.
      unless unfinished_jobs?(task.id) do
        summary = job_summary(task.id)

        log(task.id, "Processing task, job summary #{inspect(summary)}")

        if summary.unfinished == 0, do: finish_with_result(task, summary)
      end
    end)
  end

  defp finish_with_result(task, summary) do
    case calculate_task_result(summary, task) do
      {:ok, result} ->
        finish(task, summary.last_finished_at, result)
        publish(task)

      {:error, message} ->
        log(task.id, message)
    end
  end

  defp unfinished_jobs?(task_id) do
    Job
    |> where([j], j.build_id == ^task_id)
    |> where([j], j.aasm_state != "finished")
    |> Repo.exists?()
  end

  @doc """
  Counts the jobs of a task by state and result in one aggregate query.
  """
  def job_summary(task_id) do
    Job
    |> where([j], j.build_id == ^task_id)
    |> select([j], %{
      total: count(j.id),
      unfinished: filter(count(j.id), j.aasm_state != "finished"),
      passed: filter(count(j.id), j.result == "passed"),
      failed: filter(count(j.id), j.result == "failed"),
      stopped: filter(count(j.id), j.result == "stopped"),
      last_finished_at: max(j.finished_at)
    })
    |> Repo.one()
  end

  def finish(task, last_job_finished_at, result) do
    {:ok, task} = Zebra.Models.Task.update(task, %{result: result})

    if last_job_finished_at do
      Zebra.Metrics.submit_datetime_diff(
        "task.finishing.duration",
        task.updated_at,
        clamp_to_task_creation(last_job_finished_at, task)
      )
    end

    log(task.id, "marked as finished")
  end

  @doc """
  Input: a job summary (see job_summary/1) of a task whose jobs are all finished.
  """
  def calculate_task_result(summary, task) do
    cond do
      # If fail_fast:stop is active and there's a failure, show as failed
      task.fail_fast_strategy == "stop" && summary.failed > 0 ->
        {:ok, "failed"}

      summary.stopped > 0 ->
        {:ok, "stopped"}

      summary.failed > 0 ->
        {:ok, "failed"}

      summary.passed == summary.total ->
        {:ok, "passed"}

      true ->
        {:error, "can't calculate result from #{inspect(summary)}"}
    end
  end

  def log(task_id, message) do
    Logger.info("[FINISHER][task_id: #{task_id}] #{message}")
  end

  # A task is finishable when every job has a final result. The first
  # NOT EXISTS is answered from the unfinished-jobs partial index, so running
  # tasks are discarded after one index probe; the second keeps the old
  # requirement that every job has a passed, failed or stopped result.
  @finishable_tasks_query """
    select
      b.id
    from
      builds as b
    where
      b.result is null
      and not exists (
        select 1 from jobs as j
        where j.build_id = b.id and j.aasm_state <> 'finished'
      )
      and not exists (
        select 1 from jobs as j
        where j.build_id = b.id
          and (j.result is null or j.result not in ('passed', 'failed', 'stopped'))
      )
  """

  def finishable_task_ids do
    Ecto.Adapters.SQL.query!(Repo, @finishable_tasks_query).rows
    |> Enum.map(fn [id] ->
      {:ok, id} = Ecto.UUID.load(id)

      id
    end)
  end

  def publish(task) do
    spawn(fn ->
      :timer.sleep(500)

      # give it a bit time, before publishing
      # to avoid describing on the api before the commit is written to disk

      publish_to_task_state_exchange(task)
    end)
  end

  def publish_to_task_state_exchange(task) do
    exchange_name = "task_state_exchange"
    routing_key = "finished"
    {:ok, channel} = AMQP.Application.get_channel(:task_finisher)

    message =
      InternalApi.Task.TaskFinished.encode(
        InternalApi.Task.TaskFinished.new(
          task_id: task.id,
          timestamp:
            Google.Protobuf.Timestamp.new(
              seconds: task |> task_finished_timestamp() |> DateTime.to_unix()
            )
        )
      )

    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

    log(task.id, "published task finished event")
  end

  # A task made only of lightweight copies keeps the original jobs'
  # finished_at timestamps, which predate the task itself; clamp so the
  # task never reports finishing before it was created.
  def task_finished_timestamp(task) do
    task
    |> Zebra.Models.Task.finished_at()
    |> clamp_to_task_creation(task)
  end

  defp clamp_to_task_creation(finished_at = %DateTime{}, %{created_at: created_at = %DateTime{}}) do
    case DateTime.compare(finished_at, created_at) do
      :lt -> created_at
      _ -> finished_at
    end
  end

  defp clamp_to_task_creation(finished_at, _task), do: finished_at
end
