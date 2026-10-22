defmodule Zebra.Workers.Scheduler.Selector do
  import Ecto.Query
  require Logger

  alias Zebra.Workers.Scheduler.Org

  alias __MODULE__.{Result, State}

  @doc """
  Returns an instance of Result that has three fields:

    - for_scheduling: list of job ids that are ready for scheduling
    - for_force_finish: list of jobs that needs to be failed immidiately
    - no_capacity: number of jobs per machine type that don't fit in the current quota

  There are several outcomes of job selection:

    - When MAX_PARALLEL_JOBS is 0 => we select all jobs for force fail
    - When organization is suspended => we select all jobs for force fail
    - When MAX_PARALLEL_JOBS_ON_<machine_type> is 0 => we force fail the job
    - When there is room for scheduling => we select the job for scheduling

  Jobs are considered in priority order (highest first, no priority last, then
  oldest first). A job is scheduled when both the organization quota and the
  quota of its machine type have room; otherwise it is skipped and the next
  one is considered.

  The selection never reads more enqueued jobs than can be scheduled. The
  jobs of one machine type that end up scheduled are always a prefix (in
  priority order) of that machine type's enqueued jobs, no longer than the
  free room of the organization or of the machine type. Loading only that
  prefix per machine type and merging them in priority order gives the same
  result as walking the whole backlog.
  """
  def select(org_id) do
    Watchman.benchmark("scheduler.selection", fn ->
      {:ok, org} = Org.load(org_id)

      result = Result.new(org)
      max_running_jobs = Org.max_running_jobs(org_id)

      result =
        if max_running_jobs == 0 or org.suspended == true do
          #
          # This organization can run no jobs, of any kind. We force finish all
          # the jobs immediately.
          #
          ids =
            Watchman.benchmark("scheduler.selection.loading_jobs", fn ->
              load_ids(org_id, :all)
            end)

          Result.add_for_force_finish(result, ids)
        else
          select_within_quota(org, max_running_jobs, result)
        end

      Result.finalize(result)
    end)
  end

  defp select_within_quota(org, max_running_jobs, result) do
    groups =
      Watchman.benchmark("scheduler.selection.loading_jobs", fn ->
        load_groups(org.id)
      end)
      |> Enum.map(fn group ->
        Map.put(group, :quota, get_machine_quota_for_job(group, org.id))
      end)

    #
    # Jobs whose machine type (or OS image) is not available can't run, ever.
    # We force finish them, whether or not the organization has free room.
    #
    {forbidden, allowed} = Enum.split_with(groups, fn group -> group.quota == 0 end)

    result = Result.add_for_force_finish(result, load_ids(org.id, forbidden))

    state = State.initialize_from_db(org.id)

    candidates =
      Watchman.benchmark("scheduler.selection.loading_candidates", fn ->
        load_candidates(org.id, allowed, max_running_jobs, state)
      end)

    quotas = Map.new(allowed, fn g -> {{g.machine_type, g.machine_os_image}, g.quota} end)

    {final_state, result} =
      Watchman.benchmark("scheduler.selection.filtering", fn ->
        schedule(candidates, max_running_jobs, quotas, state, result)
      end)

    record_no_capacity(result, allowed, state, final_state)
  end

  defp schedule([], _, _, state, result), do: {state, result}

  defp schedule([job | rest], max_running_jobs, quotas, state, result) do
    machine_quota = Map.fetch!(quotas, {job.machine_type, job.machine_os_image})

    cond do
      reached?(State.running_jobs(state, :all), max_running_jobs) ->
        #
        # The organization is full, nothing else can be scheduled.
        #
        {state, result}

      below?(State.running_jobs(state, job.machine_type), machine_quota) ->
        # there is room for this job! schedule it, and update the state.
        state = State.record(state, job)
        result = Result.add_for_scheduling(result, job.id)

        schedule(rest, max_running_jobs, quotas, state, result)

      true ->
        # No room on this machine type, continue with the rest of the jobs.
        schedule(rest, max_running_jobs, quotas, state, result)
    end
  end

  #
  # Every enqueued job that was neither scheduled nor force finished has no
  # capacity. Counted per machine type from the grouped counts, so the jobs
  # don't have to be loaded.
  #
  defp record_no_capacity(result, allowed, initial_state, final_state) do
    allowed
    |> Enum.reduce(%{}, fn group, acc ->
      Map.update(acc, group.machine_type, group.count, &(&1 + group.count))
    end)
    |> Enum.reduce(result, fn {machine_type, enqueued}, result ->
      scheduled =
        State.running_jobs(final_state, machine_type) -
          State.running_jobs(initial_state, machine_type)

      Result.add_no_capacity(result, machine_type, enqueued - scheduled)
    end)
  end

  #
  # Quotas that are not integers impose no limit. This mirrors how the
  # comparisons behaved when they were done against the raw values.
  #
  defp reached?(running, quota) when is_integer(quota), do: running >= quota
  defp reached?(_running, _quota), do: false

  defp below?(running, quota) when is_integer(quota), do: running < quota
  defp below?(_running, _quota), do: true

  defp room(quota, running) when is_integer(quota), do: max(quota - running, 0)
  defp room(_quota, _running), do: :infinity

  #
  # Queries. The state is a literal (not a parameter) so partial indexes on
  # aasm_state stay usable with generic plans.
  #

  defp enqueued_in_org(org_id) do
    from(j in Zebra.Models.Job,
      where: j.organization_id == ^org_id,
      where: j.aasm_state == "enqueued"
    )
  end

  defp in_priority_order(query) do
    query
    |> order_by([j], fragment("? DESC NULLS LAST, ? ASC, ? ASC", j.priority, j.enqueued_at, j.id))
  end

  defp load_groups(org_id) do
    enqueued_in_org(org_id)
    |> group_by([j], [j.machine_type, j.machine_os_image])
    |> select([j], %{
      machine_type: j.machine_type,
      machine_os_image: j.machine_os_image,
      count: count(j.id)
    })
    |> Zebra.LegacyRepo.all()
  end

  defp load_ids(_org_id, []), do: []

  defp load_ids(org_id, :all) do
    enqueued_in_org(org_id)
    |> in_priority_order()
    |> select([j], j.id)
    |> Zebra.LegacyRepo.all()
  end

  defp load_ids(org_id, groups) do
    matches_any_group =
      groups
      |> Enum.map(&matches_group/1)
      |> Enum.reduce(fn condition, acc -> dynamic([j], ^acc or ^condition) end)

    enqueued_in_org(org_id)
    |> where(^matches_any_group)
    |> in_priority_order()
    |> select([j], j.id)
    |> Zebra.LegacyRepo.all()
  end

  defp load_candidates(org_id, groups, max_running_jobs, state) do
    org_room = room(max_running_jobs, State.running_jobs(state, :all))

    groups
    |> Enum.flat_map(fn group ->
      machine_room = room(group.quota, State.running_jobs(state, group.machine_type))

      case min(org_room, machine_room) do
        0 ->
          []

        limit ->
          enqueued_in_org(org_id)
          |> where(^matches_group(group))
          |> in_priority_order()
          |> limit_to(limit)
          |> select([j], %{
            id: j.id,
            machine_type: j.machine_type,
            machine_os_image: j.machine_os_image,
            priority: j.priority,
            enqueued_at: j.enqueued_at
          })
          |> Zebra.LegacyRepo.all()
      end
    end)
    |> Enum.sort_by(&priority_order_key/1)
  end

  defp limit_to(query, :infinity), do: query
  defp limit_to(query, n), do: limit(query, ^n)

  defp matches_group(group) do
    dynamic(
      [j],
      ^field_equals(:machine_type, group.machine_type) and
        ^field_equals(:machine_os_image, group.machine_os_image)
    )
  end

  defp field_equals(field_name, nil), do: dynamic([j], is_nil(field(j, ^field_name)))
  defp field_equals(field_name, value), do: dynamic([j], field(j, ^field_name) == ^value)

  #
  # Same order as in_priority_order/1: priority DESC NULLS LAST,
  # enqueued_at ASC (NULLS LAST), id ASC.
  #
  defp priority_order_key(job) do
    priority = if is_nil(job.priority), do: {1, 0}, else: {0, -job.priority}

    enqueued_at =
      if is_nil(job.enqueued_at),
        do: {1, 0},
        else: {0, DateTime.to_unix(job.enqueued_at, :microsecond)}

    {priority, enqueued_at, job.id}
  end

  def get_machine_quota_for_job(job, org_id) do
    if Zebra.Models.Job.self_hosted?(job.machine_type) do
      if FeatureProvider.feature_enabled?("self_hosted_agents", param: org_id) do
        FeatureProvider.feature_quota("self_hosted_agents", param: org_id)
      else
        0
      end
    else
      with {:ok, machine} <- FeatureProvider.find_machine(job.machine_type, param: org_id),
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
    'add_for_scheduling' and 'add_for_force_finish' functions. They prepend,
    so a selection that schedules thousands of jobs stays linear; 'finalize'
    puts the lists back in selection order and must be called once at the end.
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
      %{result | for_scheduling: [job_id | result.for_scheduling]}
    end

    def add_for_force_finish(result, job_id) when not is_list(job_id) do
      %{result | for_force_finish: [job_id | result.for_force_finish]}
    end

    def add_for_force_finish(result, job_ids) when is_list(job_ids) do
      %{result | for_force_finish: Enum.reverse(job_ids, result.for_force_finish)}
    end

    def finalize(result) do
      %{
        result
        | for_scheduling: Enum.reverse(result.for_scheduling),
          for_force_finish: Enum.reverse(result.for_force_finish)
      }
    end

    def add_no_capacity(result, machine_type, count \\ 1)

    def add_no_capacity(result, _machine_type, count) when count <= 0, do: result

    def add_no_capacity(result, machine_type, count) do
      no_capacity =
        Map.merge(result.no_capacity, %{machine_type => count}, fn _, v1, v2 ->
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
