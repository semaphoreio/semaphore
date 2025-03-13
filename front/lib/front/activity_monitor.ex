defmodule Front.ActivityMonitor do
  @doc """
  Activity Monitor displays running pipeline, jobs, and debug sessions to
  customers. This monitor is the main entrypoint for all activity releated code.

  To use the module in a controller:

  1. Load the data with ActivityMonitor.load(org_id, user_id)
  2. Use the returned Activity structure to render information

  Example:

    activity = ActivityMonitor.load(org_id, user_id)

    inspect activity.org_name
    inspect activity.default_priority
    inspect activity.items
  """

  alias Front.ActivityMonitor

  defmodule Activity do
    use TypedStruct

    typedstruct(enforce: true) do
      field(:org_name, String.t())
      field(:org_path, String.t())
      field(:default_priority, integer())
      field(:increase_quota_link, String.t())
      field(:agent_stats, ActivityMonitor.AgentStats.t())
      field(:items, Items.t())
    end
  end

  defmodule Items do
    use TypedStruct

    typedstruct(enforce: true) do
      field(:lobby, Lobby.t())
      field(:waiting, Waiting.t())
      field(:running, Running.t())
    end
  end

  defmodule Lobby do
    use TypedStruct

    typedstruct(enforce: true) do
      # we have to go with pipelines here, since we do not know which blocks
      # will run once pipeline start to run and how many jobs from them etc.
      field(:non_visible_pipelines_count, integer)
      field(:items, Item.t())
    end
  end

  defmodule Waiting do
    use TypedStruct

    typedstruct(enforce: true) do
      field(:non_visible_job_count, integer)
      field(:items, Item.t())
    end
  end

  defmodule Running do
    use TypedStruct

    typedstruct(enforce: true) do
      field(:non_visible_job_count, integer)
      field(:items, Item.t())
    end
  end

  defmodule ItemPipeline do
    @doc """
    An ActivityMonitor item represents a logical grouping of data that is
    represented to the user.

    An Item can be a pipeline, a debug session, or a group of hidden jobs
    not visible to the customer.
    """
    use TypedStruct

    typedstruct(enforce: true) do
      # one of (Pipeline, Debug Session). For serializing/desirializing to JSON.
      field(:item_id, String.t())
      field(:item_type, String.t())
      field(:user_icon_path, String.t())
      field(:user_name, String.t())
      field(:title, String.t())
      field(:name, String.t())
      field(:workflow_path, String.t())
      field(:pipeline_path, String.t())
      field(:project_name, String.t())
      field(:project_path, String.t())
      field(:ref_type, String.t())
      field(:ref_name, String.t())
      field(:ref_path, String.t())
      field(:priority, String.t())
      field(:created_at, String.t())

      field(:job_stats, JobStats.t())
    end
  end

  defmodule ItemDebugSession do
    use TypedStruct

    typedstruct(enforce: true) do
      # one of (Pipeline, Debug Session). For serializing/desirializing to JSON.
      field(:item_id, String.t())
      field(:item_type, String.t())

      # one of (Job, Project)
      field(:debug_type, String.t())
      field(:debug_job_name, String.t())
      field(:debug_job_path, String.t())
      field(:workflow_name, String.t())
      field(:workflow_path, String.t())
      field(:pipeline_name, String.t())
      field(:pipeline_path, String.t())
      field(:project_name, String.t())
      field(:project_path, String.t())
      field(:ref_name, String.t())
      field(:ref_path, String.t())
      field(:user_icon_path, String.t())
      field(:user_name, String.t())
      field(:created_at, String.t())
      field(:job_stats, JobStats.t())
    end
  end

  defmodule JobStats do
    @moduledoc """
    Collects jobs statistics, example bellow:

    %JobStats{
      left: 10,
      running: %JobStatsRunning{
        job_count: 10,
        machine_types: %{
          "e1-standard-2" => 3,
          "e1-standard-4" => 2,
          "e1-standard-8" => 5,
        }
      },
      waiting: %JobStatsWaiting{
        job_count: 4,
        machine_types: %{
          "e1-standard-2" => 1,
          "e1-standard-4" => 2,
          "e1-standard-8" => 1,
        }
      },
    }
    """
    use TypedStruct

    typedstruct(enforce: true) do
      field(:left, integer())
      field(:waiting, JobStatsWaiting)
      field(:running, JobStatsRunning)
    end
  end

  defmodule JobStatsWaiting do
    use TypedStruct

    typedstruct(enforce: true) do
      field(:job_count, integer())
      field(:machine_types, Map.t())
    end
  end

  defmodule JobStatsRunning do
    use TypedStruct

    typedstruct(enforce: true) do
      field(:job_count, integer())
      field(:machine_types, Map.t())
    end
  end

  @spec load(String.t(), String.t(), Map.t()) :: Activity.t() | {:error, String.t()}
  def load(org_id, user_id, tracing_headers \\ %{}) do
    Front.ActivityMonitor.Repo.load(org_id, user_id, tracing_headers)
    |> case do
      {:ok, data} ->
        agent_stats =
          ActivityMonitor.AgentStats.load(org_id)
          |> ActivityMonitor.AgentStats.load_activity(data)

        items = create_items(data)

        struct!(Activity,
          org_name: data.org.name,
          org_path: "/organization",
          default_priority: 50,
          increase_quota_link: "/increase_quota",
          agent_stats: agent_stats,
          items: items
        )

      {:error, _} = error ->
        error
    end
  end

  def item_type_pipeline, do: "Pipeline"
  def item_type_debug, do: "Debug Session"

  def valid_item_type?(item_type) do
    item_type == item_type_pipeline() || item_type == item_type_debug()
  end

  defp create_items(data) do
    all_items =
      data.active_debug_sessions
      |> Enum.map(fn debug -> to_pipeline_like_object(debug) end)
      |> Enum.concat(data.active_pipelines)

    accessible_project_ids = Enum.map(data.accessable_projects, fn p -> p.id end)

    struct!(Items,
      lobby: create_lobby(all_items, data, accessible_project_ids),
      waiting: create_waiting(all_items, data, accessible_project_ids),
      running: create_running(all_items, data, accessible_project_ids)
    )
  end

  defp to_pipeline_like_object(debug) do
    %{
      debug_type: debug.type,
      debug_session_id: debug.debug_session.id,
      debugged_job: debug.debugged_job,
      # matched pipeline structure for easier processing
      requester_id: debug.debug_user_id,
      promoter_id: "",
      created_at: debug.debug_session.timeline.created_at,
      state: :RUNNING,
      project_id: debug.debug_session.project_id,
      blocks: [
        %{
          state: :RUNNING,
          jobs: [debug.debug_session]
        }
      ]
    }
  end

  def create_lobby(all_items, data, accessible_project_ids) do
    {visible, non_visible} =
      all_items
      |> Enum.filter(fn pipeline -> pipeline.state == :QUEUING end)
      |> Enum.split_with(fn i ->
        Enum.member?(accessible_project_ids, i.project_id)
      end)

    non_visible_pipelines_count = length(non_visible)

    struct!(Lobby,
      non_visible_pipelines_count: non_visible_pipelines_count,
      items: transform_into_items(visible, data)
    )
  end

  def create_waiting(all_items, data, accessible_project_ids) do
    {visible, non_visible} =
      all_items
      |> Enum.reject(fn pipeline ->
        pipeline.state == :QUEUING or all_jobs_stated?(pipeline.blocks)
      end)
      |> Enum.split_with(fn i ->
        Enum.member?(accessible_project_ids, i.project_id)
      end)

    non_visible_job_count =
      non_visible
      |> transform_into_items(data)
      |> Enum.map(fn i -> i.job_stats.waiting.job_count end)
      |> Enum.sum()

    struct!(Waiting,
      non_visible_job_count: non_visible_job_count,
      items: transform_into_items(visible, data)
    )
  end

  def create_running(all_items, data, accessible_project_ids) do
    {visible, non_visible} =
      all_items
      |> Enum.reject(fn pipeline -> pipeline.state == :QUEUING end)
      |> Enum.filter(fn pipeline -> all_jobs_stated?(pipeline.blocks) end)
      |> Enum.split_with(fn i ->
        Enum.member?(accessible_project_ids, i.project_id)
      end)

    non_visible_job_count =
      non_visible
      |> transform_into_items(data)
      |> Enum.map(fn i -> i.job_stats.running.job_count end)
      |> Enum.sum()

    struct!(Running,
      non_visible_job_count: non_visible_job_count,
      items: transform_into_items(visible, data)
    )
  end

  defp all_jobs_stated?(blocks) do
    at_least_one_block_running(blocks) and all_scheduled_jobs_started(blocks)
  end

  defp at_least_one_block_running(blocks) do
    Enum.reduce_while(blocks, false, fn block, _ ->
      if block.state == :RUNNING do
        {:halt, true}
      else
        {:cont, false}
      end
    end)
  end

  defp all_scheduled_jobs_started(blocks) do
    Enum.reduce_while(blocks, true, fn block, _ ->
      if block.state == :RUNNING do
        scheduled_jobs_in_block_started?(block.jobs)
      else
        {:cont, true}
      end
    end)
  end

  defp scheduled_jobs_in_block_started?(jobs) do
    jobs
    |> Enum.reduce_while(true, fn job, _ ->
      if Map.get(job, :state) == :STARTED or
           (Map.get(job, :status) == "scheduled" and job |> Map.get(:state) |> is_nil) do
        {:cont, true}
      else
        {:halt, false}
      end
    end)
    |> if do
      {:cont, true}
    else
      {:halt, false}
    end
  end

  defp transform_into_items(entities, data) do
    entities
    |> Enum.map(fn entity ->
      project = get_project(data.accessable_projects, entity.project_id)
      user = get_user(data.users, entity, entity.requester_id, entity.promoter_id)

      transform_into_item(user, project, entity)
    end)
  end

  defp transform_into_item(user, project, debug = %{debug_type: :JOB}) do
    struct!(ItemDebugSession,
      item_id: debug.debug_session_id,
      item_type: "Debug Session",
      debug_type: "Job",
      debug_job_name: debug.debugged_job.name,
      debug_job_path: "/jobs/#{debug.debugged_job.id}",
      workflow_name: commit_message_to_item_title(debug.debugged_job.pipeline.commit_message),
      workflow_path: "/workflows/#{debug.debugged_job.pipeline.wf_id}",
      pipeline_name: debug.debugged_job.pipeline.name,
      pipeline_path:
        "/workflows/#{debug.debugged_job.pipeline.wf_id}" <>
          "?pipeline_id=#{debug.debugged_job.ppl_id}",
      project_name: project.name,
      project_path: "/projects/#{project.name}",
      ref_name: ref_name(debug.debugged_job.pipeline.branch_name),
      ref_path: "/branches/#{debug.debugged_job.branch_id}",
      user_icon_path: get_user_avatar(user),
      user_name: get_user_name(user),
      created_at: debug.created_at,
      job_stats: calc_stats(debug.blocks)
    )
  end

  defp transform_into_item(user, project, pipeline) do
    struct!(ItemPipeline,
      item_id: pipeline.ppl_id,
      item_type: "Pipeline",
      user_icon_path: get_user_avatar(user),
      user_name: get_user_name(user),
      title: commit_message_to_item_title(pipeline.commit_message),
      name: pipeline.name,
      workflow_path: "/workflows/#{pipeline.wf_id}",
      pipeline_path: "/workflows/#{pipeline.wf_id}" <> "?pipeline_id=#{pipeline.ppl_id}",
      project_name: project.name,
      project_path: "/projects/#{project.name}",
      priority: pipeline.priority,
      ref_type: ref_type(pipeline.git_ref_type),
      ref_name: pipeline.git_ref,
      ref_path: "/branches/#{pipeline.branch_id}",
      created_at: pipeline.created_at,
      job_stats: calc_stats(pipeline.blocks)
    )
  end

  @default_user_avatar_url "#{Application.compile_env(:front, :assets_path)}/images/semaphore-logo-sign-black.svg"

  defp get_user_avatar(nil), do: @default_user_avatar_url
  defp get_user_avatar(user), do: user.avatar_url || @default_user_avatar_url

  defp get_user_name(nil), do: Application.get_env(:front, :default_user_name)
  defp get_user_name(user), do: user.name || Application.get_env(:front, :default_user_name)

  defp ref_name("refs/tags/" <> ref_name), do: ref_name
  defp ref_name("pull-request-" <> ref_name), do: ref_name
  defp ref_name(ref_name), do: ref_name

  defp ref_type(:TAG), do: "Tag"
  defp ref_type(:PR), do: "Pull request"
  defp ref_type(_), do: "Branch"

  defp commit_message_to_item_title(commit_message) do
    Regex.split(~r/\r|\n|\r\n/, String.trim(commit_message)) |> Enum.at(0)
  end

  defp get_project(projects, project_id) do
    default = %{name: "hidden"}
    projects |> Enum.find(default, fn %{id: id} -> id == project_id end)
  end

  defp get_user(_users, pipeline, "", promoter_id)
       when promoter_id in ["", "Pipeline Done request"] do
    %{
      name: pipeline.commiter_username,
      avatar_url: pipeline.commiter_avatar_url
    }
  end

  defp get_user(users, _pipeline, requester_id, promoter_id)
       when promoter_id in ["", "Pipeline Done request"] do
    users |> Enum.find(fn %{id: id} -> id == requester_id end)
  end

  defp get_user(users, _pipeline, _requester_id, promoter_id) do
    users |> Enum.find(fn %{id: id} -> id == promoter_id end)
  end

  defp calc_stats(blocks) do
    init_struct =
      struct!(JobStats,
        left: 0,
        running:
          struct!(JobStatsRunning,
            job_count: 0,
            machine_types: %{}
          ),
        waiting:
          struct!(JobStatsWaiting,
            job_count: 0,
            machine_types: %{}
          )
      )

    calc_stats_(blocks, init_struct)
  end

  defp calc_stats_(blocks, init_struct) do
    Enum.reduce(blocks, init_struct, fn block, acc ->
      Enum.reduce(block.jobs, acc, fn job, stats = %{running: running, waiting: waiting} ->
        cond do
          Map.get(job, :status) == "pending" ->
            struct!(JobStats,
              left: stats.left + 1,
              running: stats.running,
              waiting: stats.waiting
            )

          Map.get(job, :state) == :STARTED ->
            struct!(JobStats,
              left: stats.left,
              running: update_stats(running, job, JobStatsRunning),
              waiting: waiting
            )

          Map.get(job, :state) != nil ->
            struct!(JobStats,
              left: stats.left,
              running: running,
              waiting: update_stats(waiting, job, JobStatsWaiting)
            )

          true ->
            stats
        end
      end)
    end)
  end

  defp update_stats(%{job_count: count, machine_types: types}, job, struct) do
    count = count + 1

    types =
      case Map.get(types, job.machine_type) do
        nil ->
          types |> Map.put(job.machine_type, 1)

        value ->
          types |> Map.put(job.machine_type, value + 1)
      end

    struct!(struct, job_count: count, machine_types: types)
  end
end
