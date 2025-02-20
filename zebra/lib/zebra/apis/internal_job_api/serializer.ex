defmodule Zebra.Apis.InternalJobApi.Serializer do
  alias InternalApi.ServerFarm.Job.Job, as: Job

  def serialize_jobs(jobs) do
    jobs |> Enum.map(fn j -> serialize_job(j) end)
  end

  def serialize_job(job) do
    alias Zebra.Models.Debug

    job = Zebra.LegacyRepo.preload(job, [:task])

    {is_debug_job, debug_user_id} =
      case Debug.find_by_job_id(job.id) do
        {:ok, debug} -> {true, debug.user_id}
        _ -> {false, ""}
      end

    timeline =
      Job.Timeline.new(
        Zebra.Apis.Utils.encode_timestamps(
          created_at: job.created_at,
          enqueued_at: job.enqueued_at,
          started_at: job.started_at,
          execution_started_at: job.started_at,
          execution_finished_at: job.finished_at,
          finished_at: job.finished_at
        )
      )

    [
      id: job.id,
      name: try_or(job, :name),
      index: job.index,
      state: job_state(job.aasm_state),
      result: job_result(job.result),
      timeline: timeline,
      failure_reason: try_or(job, :failure_reason),
      machine_type: try_or(job, :machine_type),
      machine_os_image: try_or(job, :machine_os_image),
      agent_host: try_or(job, :agent_ip_address),
      agent_ctrl_port: try_or(job, :agent_ctrl_port),
      agent_ssh_port: try_or(job, :agent_ssh_port),
      agent_auth_token: try_or(job, :agent_auth_token),
      project_id: try_or(job, :project_id),
      organization_id: try_or(job, :organization_id),
      hook_id: try_or(job.task, :workflow_id),
      branch_id: try_or(job.task, :branch_id),
      ppl_id: try_or(job.task, :ppl_id),
      priority: job.priority,
      is_debug_job: is_debug_job,
      debug_user_id: debug_user_id,
      self_hosted: Zebra.Models.Job.self_hosted?(job.machine_type),
      build_req_id: try_or(job.task, :build_request_id),
      agent_name: try_or(job, :agent_name),
      agent_id: try_or(job, :agent_id)
    ]
    |> Zebra.Apis.Utils.remove_nils_from_keywordlist()
    |> Job.new()
  end

  def serialize_debugs(debug_jobs) do
    debug_jobs |> Enum.map(fn j -> serialize_debug(j) end)
  end

  def serialize_debug(debug_job) do
    alias InternalApi.ServerFarm.Job.DebugSession

    debug = debug_job.debug

    params = [
      debug_session: serialize_job(debug_job),
      debug_session_type: debug_session_type(debug.debugged_type),
      debug_user_id: debug.user_id || ""
    ]

    params =
      if debug.debugged_type == Zebra.Models.Debug.type_job() do
        job = Zebra.LegacyRepo.get(Zebra.Models.Job, debug.debugged_id) |> serialize_job()

        params ++ [debugged_job: job]
      else
        params
      end

    DebugSession.new(params)
  end

  defp try_or(struct_or_nil, field, or_value \\ nil) do
    if struct_or_nil do
      Map.get(struct_or_nil, field)
    else
      or_value
    end
  end

  def job_state(state) do
    case state do
      "pending" -> Job.State.value(:PENDING)
      "enqueued" -> Job.State.value(:ENQUEUED)
      "scheduled" -> Job.State.value(:SCHEDULED)
      "waiting-for-agent" -> Job.State.value(:SCHEDULED)
      "started" -> Job.State.value(:STARTED)
      "finished" -> Job.State.value(:FINISHED)
    end
  end

  def job_result(result) do
    case result do
      "passed" -> Job.Result.value(:PASSED)
      "failed" -> Job.Result.value(:FAILED)
      "stopped" -> Job.Result.value(:STOPPED)
      nil -> nil
    end
  end

  def debug_session_type(type) do
    case type do
      "project" -> InternalApi.ServerFarm.Job.DebugSessionType.value(:PROJECT)
      "job" -> InternalApi.ServerFarm.Job.DebugSessionType.value(:JOB)
    end
  end
end
