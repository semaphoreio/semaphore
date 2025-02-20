defmodule Zebra.Monitor do
  import Ecto.Query
  require Logger

  alias Zebra.LegacyRepo
  alias Zebra.Models.{Job, JobStopRequest, Task}

  #
  # Methods called from the Quantum Scheduler, defined in config/config.exs
  #

  def count_pending_jobs do
    Logger.info("Submiting pending jobs count")

    count = LegacyRepo.aggregate(Job.pending(), :count, :id)

    internal_metric = "monitor.jobs.pending"
    external_metric = {"state", [state: "pending"]}
    Watchman.submit([internal: internal_metric, external: external_metric], count)

    count
  end

  def count_enqueued_jobs do
    Logger.info("Submiting enqueued jobs count")

    count = LegacyRepo.aggregate(Job.enqueued(), :count, :id)

    internal_metric = "monitor.jobs.enqueued"
    external_metric = {"state", [state: "enqueued"]}
    Watchman.submit([internal: internal_metric, external: external_metric], count)

    count
  end

  def count_scheduled_jobs do
    Logger.info("Submiting scheduled jobs count")

    # For cloud jobs, we care about the machine type,
    # so we tag them with the machine type too
    cloud_counts = LegacyRepo.all(Job.cloud_scheduled_per_machine_type())

    if Enum.empty?(cloud_counts) do
      Watchman.submit({"monitor.jobs.scheduled", ["cloud"]}, 0)
    else
      Enum.each(cloud_counts, fn r ->
        Watchman.submit({"monitor.jobs.scheduled", ["cloud", r.machine_type]}, r.count)
      end)
    end

    # For self-hosted jobs, just the total is enough
    self_hosted_count = LegacyRepo.aggregate(Job.self_hosted_scheduled(), :count, :id)
    internal_self_hosted = {"monitor.jobs.scheduled", ["self_hosted"]}
    external_self_hosted = {"state", [state: "scheduled"]}

    Watchman.submit(
      [internal: internal_self_hosted, external: external_self_hosted],
      self_hosted_count
    )

    {cloud_counts, self_hosted_count}
  end

  def count_waiting_for_agent_jobs do
    Logger.info("Submiting waiting-for-agent jobs count")

    count = LegacyRepo.aggregate(Job.waiting_for_agent(), :count, :id)

    Watchman.submit("monitor.jobs.waiting-for-agent", count)

    count
  end

  def waiting_times do
    import Ecto.Query, only: [from: 2]

    data =
      Zebra.Machines.machine_types()
      |> Enum.map(fn agent ->
        {agent, waiting_times_for_agent_type(agent)}
      end)
      |> Enum.into(%{})

    Enum.each(data, fn {agent, buckets} ->
      Enum.each(buckets, fn {bucket, value} ->
        Watchman.submit({"monitor.jobs.waiting_for_agent", [agent, bucket]}, value, :timing)
      end)
    end)

    data
  end

  def waiting_times_for_agent_type(type) do
    secs = "extract(epoch from (now() - scheduled_at))"

    query = """
      SELECT
        COUNT(CASE WHEN (#{secs} >= 0   AND #{secs} < 3  ) THEN 1 ELSE NULL END) as from_0s_to_3s,
        COUNT(CASE WHEN (#{secs} >= 3   AND #{secs} < 10 ) THEN 1 ELSE NULL END) as from_3s_to_10s,
        COUNT(CASE WHEN (#{secs} >= 10  AND #{secs} < 30 ) THEN 1 ELSE NULL END) as from_10s_to_30s,
        COUNT(CASE WHEN (#{secs} >= 30  AND #{secs} < 60 ) THEN 1 ELSE NULL END) as from_30s_to_1m,
        COUNT(CASE WHEN (#{secs} >= 60  AND #{secs} < 180) THEN 1 ELSE NULL END) as from_1m_to_3m,
        COUNT(CASE WHEN (#{secs} >= 180 AND #{secs} < 600) THEN 1 ELSE NULL END) as from_3m_to_10m,
        COUNT(CASE WHEN (#{secs} >= 600                  ) THEN 1 ELSE NULL END) as from_10m_to_inf
      FROM
        jobs
      WHERE
        jobs.aasm_state = 'scheduled' AND jobs.machine_type = '#{type}'
    """

    case Zebra.LegacyRepo.query(query) do
      {:ok, results} ->
        Enum.zip(results.columns, hd(results.rows)) |> Enum.into(%{})

      {:error, e} ->
        Logger.error("Error executing query for #{type}: #{inspect(e)}")

        %{
          "from_0s_to_3s" => 0,
          "from_3s_to_10s" => 0,
          "from_10s_to_30s" => 0,
          "from_30s_to_1m" => 0,
          "from_1m_to_3m" => 0,
          "from_3m_to_10m" => 0,
          "from_10m_to_inf" => 0
        }
    end
  rescue
    e ->
      Logger.error("Error executing query for #{type}, returning empty result: #{inspect(e)}")

      %{
        "from_0s_to_3s" => 0,
        "from_3s_to_10s" => 0,
        "from_10s_to_30s" => 0,
        "from_30s_to_1m" => 0,
        "from_1m_to_3m" => 0,
        "from_3m_to_10m" => 0,
        "from_10m_to_inf" => 0
      }
  end

  def count_started_jobs do
    Logger.info("Submiting started jobs count")

    cloud_count = LegacyRepo.aggregate(Job.cloud_started(), :count, :id)
    self_hosted_count = LegacyRepo.aggregate(Job.self_hosted_started(), :count, :id)

    Watchman.submit({"monitor.jobs.started", ["cloud"]}, cloud_count)

    internal_self_hosted = {"monitor.jobs.started", ["self_hosted"]}
    external_self_hosted = {"state", [state: "started"]}

    Watchman.submit(
      [internal: internal_self_hosted, external: external_self_hosted],
      self_hosted_count
    )

    {cloud_count, self_hosted_count}
  end

  def count_stuck_jobs do
    Logger.info("Submiting stuck jobs count")

    count = LegacyRepo.aggregate(stuck_jobs(), :count, :id)

    internal = "monitor.jobs.stuck"
    external = {"state", [state: "stuck"]}
    Watchman.submit([internal: internal, external: external], count)

    count
  end

  def count_inconsistent_jobs do
    Logger.info("Submiting inconsistent jobs count")

    count = LegacyRepo.aggregate(inconsistent_jobs(), :count, :id)

    internal = "monitor.jobs.inconsistent"
    external = {"state", [state: "inconsistent"]}
    Watchman.submit([internal: internal, external: external], count)

    count
  end

  def count_running_tasks do
    Logger.info("Submiting running task count")

    count = LegacyRepo.aggregate(Task.running(), :count, :id)

    Watchman.submit("monitor.tasks.running", count)

    count
  end

  def count_pending_job_stop_requests do
    Logger.info("Submiting pending job-stop-requests count")

    count = LegacyRepo.aggregate(JobStopRequest.pending(), :count, :id)

    Watchman.submit("monitor.job_stop_requests.pending", count)

    count
  end

  #
  # Helper methods for debugging and querying
  #

  @default_time_limit 60 * 60 * 3

  def stuck_jobs do
    from(j in Job,
      where: j.aasm_state == "started",
      where:
        fragment(
          "extract(epoch from ?) + coalesce(?, ?)",
          j.started_at,
          j.execution_time_limit,
          @default_time_limit
        ) < fragment("extract(epoch from ?)", ago(10, "minute"))
    )
  end

  @doc """
  Query for jobs that are either:

  - Finished without result
  - Non-finished with a result

  Both states are broken, and means that we have a deeper problem in the system.
  """
  def inconsistent_jobs do
    # search by concrete states is optimized, search by != "<state>" is not
    non_finished_states =
      Job.valid_states()
      |> Enum.filter(fn s ->
        s != Job.state_finished()
      end)

    from(j in Job,
      where:
        j.aasm_state in ^non_finished_states and
          not is_nil(j.result) and
          j.created_at > date_add(^Date.utc_today(), -1, "day")
    )
  end

  def stop_jobs_on_suspended_orgs do
    Job.started()
    |> where([j], j.started_at < from_now(-5, "minute"))
    |> LegacyRepo.all()
    |> Enum.each(fn j ->
      Logger.info("Testing #{j.id} #{j.started_at}")

      case Zebra.Workers.Scheduler.Org.load(j.organization_id) do
        {:ok, org} ->
          if org.suspended do
            Zebra.Workers.JobStopper.request_stop_async(j)
          end

        _ ->
          Logger.error("Failed to load org for #{j.id}")
      end
    end)
  end
end
