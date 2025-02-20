defmodule Zebra.Workers.TaskFailFast do
  alias Zebra.LegacyRepo, as: Repo

  require Logger

  @doc """
  The Task Fail Fast worker implements the strategies for Fail-Fast on task level.

  There are three Fail-Fast strategies:

    - NONE (default): All jobs are executed independently until they finish

    - CANCEL: When any job fails:
      - Cancel all jobs that did not start (e.g. capacity quota)
      - Let all running jobs finish.

    - STOP: When any job fails:
      - Stop all jobs that are not done.

  This worker **does not finish** the task. It only stops the jobs. The worker
  that is responsible for finishing a task and calculating its result is
  TaskFinisher.
  """

  def start_link do
    {:ok, spawn_link(&loop/0)}
  end

  def loop do
    Task.async(fn -> tick() end) |> Task.await(:infinity)

    :timer.sleep(1000)

    loop()
  end

  def tick do
    stop = Task.async(fn -> process("stop") end)
    cancel = Task.async(fn -> process("cancel") end)

    Task.await(stop, :infinity)
    Task.await(cancel, :infinity)
  end

  def process(strategy) do
    Watchman.benchmark({"task_fast_fail.process.duration", [strategy]}, fn ->
      Zebra.LegacyRepo.transaction(fn ->
        task_job_tuples = query(strategy) |> Repo.all()

        if task_job_tuples != [] do
          Logger.info("Fail-Fast '#{strategy}' activated for #{inspect(task_job_tuples)}")
        end

        Zebra.Models.JobStopRequest.bulk_create(task_job_tuples)
      end)
    end)
  end

  @doc """
  Returns a list of {task_id, job_id} tuples that need to be stopped.

  The selected jobs need to satisfy the following
    - task is not yet finished
    - job has no job stop request
    - job is in the 'job-states' state
    - task has at least one failed job
  """
  def query(strategy) do
    import Ecto.Query

    from(j in Zebra.Models.Job,
      lock: "FOR UPDATE OF j0 SKIP LOCKED",
      left_join: job_stop_request in assoc(j, :job_stop_request),
      where: is_nil(job_stop_request.id),
      where: j.aasm_state in ^job_states(strategy),
      where:
        j.build_id in fragment(
          """
            select builds.id
            from builds
            inner join jobs as j2 on builds.id = j2.build_id
            where builds.fail_fast_strategy = ? and j2.result = 'failed'
          """,
          ^strategy
        ),
      select: {j.build_id, j.id}
    )
  end

  def job_states("stop"), do: ["pending", "enqueued", "scheduled", "waiting-for-agent", "started"]
  def job_states("cancel"), do: ["pending", "enqueued", "scheduled", "waiting-for-agent"]
end
