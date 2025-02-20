defmodule Zebra.Workers.WaitingJobTerminator do
  @doc """
  Worker responsible for looking up jobs that are waiting for agents for more than 24h.

  Termination is done by creating a Job Stop Request. Look into the JobStopper
  worker for more information.
  """

  require Logger

  alias Zebra.Models.Job

  def start_link do
    {:ok, spawn_link(&loop/0)}
  end

  def loop do
    Task.async(fn -> tick() end) |> Task.await(:infinity)

    :timer.sleep(60_000)

    loop()
  end

  def tick do
    Watchman.benchmark("waiting_job_terminator.process.duration", fn ->
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
    - job is in scheduled state longer than MAX_SCHEDULED_TIME_IN_SECONDS
    - job was not already stopped
  """
  def query do
    import Ecto.Query, only: [from: 2]

    max_scheduled_time =
      String.to_integer(Zebra.Config.fetch!(__MODULE__, :max_scheduled_time_in_seconds))

    states = [Job.state_waiting_for_agent(), Job.state_scheduled()]

    from(j in Job,
      lock: "FOR UPDATE OF j0 SKIP LOCKED",
      left_join: job_stop_request in assoc(j, :job_stop_request),
      where: is_nil(job_stop_request.id),
      where: j.aasm_state in ^states,
      where:
        fragment(
          "extract(epoch from ?) + ?",
          j.scheduled_at,
          ^max_scheduled_time
        ) < fragment("extract(epoch from now())"),
      select: {j.build_id, j.id}
    )
  end
end
