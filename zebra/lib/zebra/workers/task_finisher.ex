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
      jobs =
        Zebra.Models.Job
        |> where([j], j.build_id == ^task.id)
        |> select([j], [:aasm_state, :result, :finished_at])
        |> Repo.all()

      states = Enum.map(jobs, fn j -> j.aasm_state end)
      results = Enum.map(jobs, fn j -> j.result end)

      log(task.id, "Processing task, results #{inspect(results)}, states #{inspect(states)}")

      if Enum.all?(states, fn s -> s == Job.state_finished() end) do
        case calculate_task_result(results, task) do
          {:ok, result} ->
            finish(task, jobs, result)
            publish(task)

          {:error, message} ->
            log(task.id, message)
        end
      end
    end)
  end

  def finish(task, jobs, result) do
    {:ok, task} = Zebra.Models.Task.update(task, %{result: result})

    last_job_finished_at =
      jobs
      |> Enum.map(fn j -> j.finished_at end)
      |> Enum.max_by(fn t ->
        Zebra.Time.datetime_to_ms(t)
      end)

    Zebra.Metrics.submit_datetime_diff(
      "task.finishing.duration",
      task.updated_at,
      last_job_finished_at
    )

    log(task.id, "marked as finished")
  end

  def calculate_task_result(job_results, task) do
    cond do
      # If fail_fast:stop is active and there's a failure, show as failed
      task.fail_fast_strategy == "stop" &&
          Enum.any?(job_results, fn r -> r == Job.result_failed() end) ->
        {:ok, "failed"}

      Enum.any?(job_results, fn r -> r == Job.result_stopped() end) ->
        {:ok, "stopped"}

      Enum.any?(job_results, fn r -> r == Job.result_failed() end) ->
        {:ok, "failed"}

      Enum.all?(job_results, fn r -> r == Job.result_passed() end) ->
        {:ok, "passed"}

      true ->
        {:error, "can't calculate result from #{inspect(job_results)}"}
    end
  end

  def log(task_id, message) do
    Logger.info("[FINISHER][task_id: #{task_id}] #{message}")
  end

  @finishable_tasks_query """
    select
      running.id
    from
      (
        select
          b.id,
          (select count(*) from jobs where build_id = b.id)                        as total_jobs,
          (select count(*) from jobs where build_id = b.id and result = 'passed')  as passed_jobs,
          (select count(*) from jobs where build_id = b.id and result = 'failed')  as failed_jobs,
          (select count(*) from jobs where build_id = b.id and result = 'stopped') as stopped_jobs
        from
          builds as b
        where
          b.result IS NULL
      ) as running
    where
      running.total_jobs = running.passed_jobs + running.failed_jobs + running.stopped_jobs
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
              seconds: Zebra.Models.Task.finished_at(task) |> DateTime.to_unix()
            )
        )
      )

    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

    log(task.id, "published task finished event")
  end
end
