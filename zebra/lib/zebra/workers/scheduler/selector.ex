defmodule Zebra.Workers.Scheduler.Selector do
  import Ecto.Query
  require Logger

  alias Zebra.Workers.Scheduler.Org

  @doc """
  Returns an instance of Result that has two fields:

    - for_scheduling: list of job ids that are ready for scheduling
    - for_force_fail: list of jobs that needs to be failed immidiately
    - no_capacity: list of jobs that don't fit in the current quota

  There are several outcomes of job selection:

    - When MAX_PARALLEL_JOBS is 0 => we select all jobs for force fail
    - When organization is suspended => we select all jobs for force fail
    - When MAX_PARALLEL_JOBS_ON_<machine_type> is 0 => we force fail the job
    - When there is room for scheduling => we select the job for scheduling
  """
  def select(org_id) do
    Watchman.benchmark("scheduler.selection", fn ->
      jobs =
        Watchman.benchmark("scheduler.selection.loading_jobs", fn ->
          Zebra.Models.Job.enqueued()
          |> where([j], j.organization_id == ^org_id)
          |> order_by([j], fragment("? DESC NULLS LAST, ? ASC", j.priority, j.enqueued_at))
          |> select([j], [:id, :machine_type, :machine_os_image])
          |> lock("FOR UPDATE")
          |> Zebra.LegacyRepo.all()
        end)

      {:ok, org} = Zebra.Workers.Scheduler.Org.load(org_id)

      state = __MODULE__.State.initialize_from_db(org_id)

      result = __MODULE__.Result.new(org)

      Watchman.benchmark("scheduler.selection.filtering", fn ->
        select(jobs, org, state, result)
      end)
    end)
  end

  defp select([], _, _, result), do: result

  defp select(jobs = [job | rest], org, state, result) do
    alias __MODULE__.{State, Result}
    {machine_type, _} = Zebra.Workers.Agent.HostedAgent.translate_machine(job)

    running_jobs_for_machine_type = State.running_jobs(state, machine_type)
    machine_quota = get_machine_quota_for_job(job, org.id)
    org_id = org.id

    cond do
      Org.max_running_jobs(org_id) == 0 ->
        #
        # This organization can run no jobs, of any kind. We force finish all
        # the jobs immediately.
        #
        # There is no need to continue the selection further. Returning the
        # result.
        #
        job_ids = Enum.map(jobs, fn j -> j.id end)
        result = Result.add_for_force_finish(result, job_ids)

        result

      org.suspended == true ->
        #
        # This organization is supended and can run no jobs, of any kind.
        # We force finish all the jobs immediately.
        #
        # There is no need to continue the selection further. Returning the
        # result.
        #
        job_ids = Enum.map(jobs, fn j -> j.id end)
        result = Result.add_for_force_finish(result, job_ids)

        result

      machine_quota == 0 ->
        #
        # Can't run this job, ever. We need to force finish it.
        #
        result = Result.add_for_force_finish(result, job.id)

        select(rest, org, state, result)

      State.running_jobs(state, :all) >= Org.max_running_jobs(org_id) ->
        #
        # Can't run this job, continuing selection on the rest of the jobs.
        #
        # At this point, we could also stop the selection because no other job
        # can be scheduled, however we continue in order to look up all the jobs
        # that need to be force finished.
        #
        result = Result.add_no_capacity(result, machine_type)
        select(rest, org, state, result)

      running_jobs_for_machine_type < machine_quota ->
        # there is room for this job! schedule it, and update the state.
        state = State.record(state, job)
        result = Result.add_for_scheduling(result, job.id)

        select(rest, org, state, result)

      running_jobs_for_machine_type >= machine_quota ->
        # Can't run this job, continue selection on the rest of the jobs.
        result = Result.add_no_capacity(result, machine_type)
        select(rest, org, state, result)

      true ->
        raise "Unrecognized job scheduling condition"
    end
  end

  def get_machine_quota_for_job(job, org_id) do
    if Zebra.Models.Job.self_hosted?(job.machine_type) do
      if FeatureProvider.feature_enabled?("self_hosted_agents", param: org_id) do
        FeatureProvider.feature_quota("self_hosted_agents", param: org_id)
      else
        0
      end
    else
      with {machine_type, _} <- Zebra.Workers.Agent.HostedAgent.translate_machine(job),
           {:ok, machine} <- FeatureProvider.find_machine(machine_type, param: org_id),
           true <- FeatureProvider.Machine.enabled?(machine),
           true <- Enum.member?(machine.available_os_images, job.machine_os_image),
           quota <- FeatureProvider.Machine.quota(machine) do
        quota
      else
        _ -> 0
      end
    end
  end

  defmodule Result do
    @doc """
    Represents the result returned by the selection algorithm.

    It contains:
      - for_scheduling: list of job_ids that are ready for scheduling
      - for_force_finish: list of job_ids that need to be failed immidiately
      - no_capacity: number of jobs that are not scheduled because of capacity limits
      - org_username: username of the org

    During the selection process, these values are updated with the
    'add_for_scheduling' and 'add_for_force_finish' functions.
    """

    defstruct [:for_scheduling, :for_force_finish, :no_capacity, :org_username]

    def new(org) do
      init_no_capacity =
        Zebra.Machines.machine_types(org.id)
        |> Enum.map(fn type -> {type, 0} end)
        |> Enum.into(%{})

      %__MODULE__{
        for_scheduling: [],
        for_force_finish: [],
        no_capacity: init_no_capacity,
        org_username: org.username
      }
    end

    def add_for_scheduling(result, job_id) do
      %{result | for_scheduling: result.for_scheduling ++ [job_id]}
    end

    def add_for_force_finish(result, job_id) when not is_list(job_id) do
      %{result | for_force_finish: result.for_force_finish ++ [job_id]}
    end

    def add_for_force_finish(result, job_ids) when is_list(job_ids) do
      %{result | for_force_finish: result.for_force_finish ++ job_ids}
    end

    def add_no_capacity(result, machine_type) do
      no_capacity =
        Map.merge(result.no_capacity, %{machine_type => 1}, fn _, v1, v2 ->
          (v1 || 0) + v2
        end)

      %{result | no_capacity: no_capacity}
    end
  end

  defmodule State do
    @doc """
    Represents the state of the selection algorithm.

    Initialy, we load the current state from the DB, and further on we just
    update the counters in memory. This way we avoid any unnecessary hits to
    the database.

    The state of the selection algorithm contains:

    - The (currently known) number of running jobs
    - The (currently known) number of running jobs per machine type

    It exposes two operations:

    - running_jobs: Getting the number of running jobs
      - with the :all parameter => returns total_running_jobs
      - with machine_type parameter => returns number of jobs or if such
        machine type is unknown 0

    - record: Updates the in-memory counter of the currently known running jobs
    """

    defstruct [:total_running_jobs, :per_machine_type]

    def initialize_from_db(org_id) do
      Watchman.benchmark("scheduler.selection.state.initialize_from_db", fn ->
        query =
          from(j in Zebra.Models.Job,
            where: j.organization_id == ^org_id,
            where: j.aasm_state in ["scheduled", "started"],
            group_by: j.machine_type,
            select: {j.machine_type, fragment("count(*)")}
          )

        per_machine_type = Zebra.LegacyRepo.all(query) |> Enum.into(%{})

        total_running_jobs =
          per_machine_type
          |> Enum.map(fn {_, v} -> v end)
          |> Enum.sum()

        %__MODULE__{
          total_running_jobs: total_running_jobs,
          per_machine_type: per_machine_type
        }
      end)
    end

    def running_jobs(state, :all) do
      state.total_running_jobs
    end

    def running_jobs(state, machine_type) do
      Map.get(state.per_machine_type, machine_type, 0)
    end

    def record(state, job) do
      %{
        state
        | total_running_jobs: state.total_running_jobs + 1,
          per_machine_type:
            Map.update(
              state.per_machine_type,
              job.machine_type,
              1,
              fn v -> v + 1 end
            )
      }
    end
  end
end
