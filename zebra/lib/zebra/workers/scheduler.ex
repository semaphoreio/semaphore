defmodule Zebra.Workers.Scheduler do
  require Logger

  @doc """
  The Scheduler is responsible moving jobs from enqueued to scheduled state.

  This transition is limited by two factors:

    - The MAX_PARALLEL_JOBS quota in an organization
    - The MAX_PARALLEL_JOBS_ON_<MACHINE_TYPE> quota in an organization

  A job needs to satisfy both quotas in order to transition from enqueued to
  scheduled.

  The worker is processing organizations one by one, and applies the transition
  to the _oldest jobs first_.

  If any of the quotas is set to 0, the job is automatically transitioned to
  failed with an appropriate failure messages that indicates the quota limit.

  This worker processes organization in parallel. To control the parallelism,
  set the __MODULE__.batch_size application configuration.

  The default value of the parallelism is set to 10.
  """

  import Ecto.Query

  def start_link do
    {:ok, spawn_link(&loop/0)}
  end

  def loop do
    Task.async(fn -> tick() end) |> Task.await(:infinity)

    #
    # Loops are pretty infrequent.
    #
    # This is because we expect most of the scheduling to be done
    # by the callback in job.enqueue and job.finish.
    #
    # The loop is here as a safeguard to handle missed events.
    #
    # We randomize the sleep period to reduce collision between pods.
    #
    sleep_period = Enum.random(10_000..30_000)
    :timer.sleep(sleep_period)

    loop()
  end

  @doc """
  On every tick, we load all the organization ids that have an enqueued job.

  For every organization, we try to acquire a DB lock, and process all the jobs.
  """
  def tick do
    Logger.info("Tick")

    org_ids =
      Watchman.benchmark("scheduler.tick.loading_org_ids", fn ->
        Zebra.Models.Job.enqueued()
        |> distinct([j], j.organization_id)
        |> select([j], j.organization_id)
        |> Zebra.LegacyRepo.all()
      end)

    Logger.info("Try to schedule jobs for organizations #{inspect(org_ids)}")
    batch_size = Zebra.Config.fetch!(__MODULE__, :batch_size)

    org_ids
    |> Zebra.Parallel.stream(
      [metadata: [__MODULE__], max_concurrency: batch_size, timeout: 10_000],
      fn org_id ->
        lock_and_process(org_id)
      end
    )
  end

  #
  # This method is called from Job.enqueue and Job.finished to trigger a
  # scheduling call for the organization asynchroniously.
  #
  def lock_and_process_async(org_id) do
    spawn(fn ->
      #
      # The timeout is not really necessary
      # but it can act as a safeguard to avoid race conditions with
      # transactions blocks from the caller.
      #
      :timer.sleep(100)

      Zebra.Workers.Scheduler.lock_and_process(org_id)
    end)
  end

  def lock_and_process(org_id) do
    Watchman.benchmark("scheduler.process.duration", fn ->
      Zebra.LegacyRepo.transaction(fn ->
        Zebra.Lock.advisory(org_id, fn ->
          result = Zebra.Workers.Scheduler.Selector.select(org_id)

          Logger.info("[#{org_id}] No capacity: #{inspect(result.no_capacity)}")
          submit_no_capacity_metrics(result)

          Logger.info("[#{org_id}] Scheduling: #{inspect(result.for_scheduling)}")
          Zebra.Models.Job.bulk_schedule(result.for_scheduling)

          Logger.info("[#{org_id}] Force Finishing: #{inspect(result.for_force_finish)}")

          Zebra.Models.Job.bulk_force_finish(
            result.for_force_finish,
            "Selected machine type is not available in this organization"
          )
        end)
      end)
    end)
  end

  def submit_no_capacity_metrics(scheduling_result) do
    spawn(fn ->
      scheduling_result.no_capacity
      |> Enum.each(fn {machine_type, value} ->
        tags = [scheduling_result.org_username, machine_type]

        Watchman.submit({"scheduler.no_capacity", tags}, value, :timing)
      end)
    end)
  end
end
