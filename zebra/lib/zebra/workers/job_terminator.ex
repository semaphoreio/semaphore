defmodule Zebra.Workers.JobTerminator do
  @doc """
  Worker responsible for looking up jobs that are running longer than their
  execution time limit and terminating them.

  Termination is done by creating a Job Stop Request. Look into the JobStopper
  worker for more information.
  """

  require Logger

  # default time limit is 24hours
  @default_time_limit 60 * 60 * 24

  def start_link do
    {:ok, spawn_link(&loop/0)}
  end

  def loop do
    Task.async(fn -> tick() end) |> Task.await(:infinity)

    :timer.sleep(60_000)

    loop()
  end

  def tick do
    Watchman.benchmark("job_terminator.process.duration", fn ->
      Zebra.LegacyRepo.transaction(fn ->
        ids = query() |> Zebra.LegacyRepo.all()

        Logger.info("Terminating #{inspect(ids)}")

        Zebra.Models.JobStopRequest.bulk_create(ids)
      end)
    end)
  end

  @doc """
  Returns a list of {task_id, job_id} tuples that need to be stopped.

  The selected jobs need to satisfy the following
    - job is running longer than execution time limit
    - job was not already stopped
  """
  def query do
    import Ecto.Query, only: [from: 2]

    from(j in Zebra.Models.Job,
      lock: "FOR UPDATE OF j0 SKIP LOCKED",
      left_join: job_stop_request in assoc(j, :job_stop_request),
      where: is_nil(job_stop_request.id),
      where: j.aasm_state == "started",
      where:
        fragment(
          "extract(epoch from ?) + coalesce(?, ?)",
          j.started_at,
          j.execution_time_limit,
          @default_time_limit
        ) < fragment("extract(epoch from now())"),
      select: {j.build_id, j.id}
    )
  end
end
