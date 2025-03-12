defmodule Zebra.Apis.InternalJobApi do
  require Logger

  use GRPC.Server, service: InternalApi.ServerFarm.Job.JobService.Service
  use Sentry.Grpc, service: InternalApi.ServerFarm.Job.JobService.Service

  alias InternalApi.ServerFarm.Job.Job.State
  alias InternalApi.ServerFarm.Job.StopResponse

  def create(req, _) do
    Watchman.benchmark("internal_job_api.create_job.duration", fn ->
      alias InternalApi.ServerFarm.Job.CreateResponse, as: Resp
      alias Zebra.Apis.InternalJobApi.Serializer, as: Serializer
      alias Zebra.Apis.InternalJobApi.Validator
      alias Zebra.Models.Job
      alias Zebra.Workers.JobRequestFactory.Secrets

      project_id = req.project_id
      org_id = req.organization_id
      user_id = req.requester_id

      Logger.info("Creating job org: #{org_id} user: #{user_id} project: #{project_id}")

      spec =
        req.job_spec
        |> Map.put(:project_id, project_id)
        |> Map.put(:epilogue_commands, [])
        |> Map.drop([:job_name, :execution_time_limit, :priority])

      job_params = %{
        organization_id: org_id,
        project_id: project_id,
        index: 0,
        machine_type: req.job_spec.agent.machine.type,
        machine_os_image: req.job_spec.agent.machine.os_image,
        execution_time_limit: req.job_spec.execution_time_limit,
        priority: req.job_spec.priority,
        name: req.job_spec.job_name,
        spec: spec
      }

       with {:ok, job_params} <- Validator.validate_job(job_params),
            {:secrets, {:ok, true}} <-
             {:secrets,
              Secrets.validate_job_secrets(
                org_id,
                job_params.spec,
                :debug
              )},
            {:ok, job} <- Job.create(job_params),
            serialized_job <- Serializer.serialize_job(job) do
              Resp.new(status: grpc_status_ok(), job: serialized_job)
      else
        {:error, :validation, message} ->
          Resp.new(status: grpc_status_bad_param(message))

        {:secrets, {:ok, false}} ->
            message = "Some secrets used in this job are blocking this operation."
            Resp.new(status: grpc_status_bad_param(message))

        {:secrets, {:error, message}} ->
          raise GRPC.RPCError, status: :internal, message: message

        {:error, message} ->
          Logger.error("Create unexpected error: #{inspect(message)}")
          raise GRPC.RPCError, status: :internal, message: "Internal error"
      end
    end)
  end

  def list(req, _) do
    Watchman.benchmark("internal_job_api.list.duration", fn ->
      alias Zebra.Apis.InternalJobApi.Lister, as: Lister
      alias Zebra.Apis.InternalJobApi.Serializer, as: Serializer
      alias InternalApi.ServerFarm.Job.ListResponse, as: Resp
      alias InternalApi.ServerFarm.Job.ListRequest.Order

      Logger.info("List #{inspect(req)}")

      finished_at_gte =
        if req.finished_at_gte do
          map_timestamp_to_ecto(req.finished_at_gte.seconds)
        else
          map_timestamp_to_ecto(0)
        end

      with {:ok, page_size} <- parse_page_size(req.page_size),
           job_states <- map_state_names(req.job_states),
           query_params <- %{
             org_id: req.organization_id,
             job_states: job_states,
             finished_at_gte: finished_at_gte,
             created_at_gte: req.created_at_gte,
             created_at_lte: req.created_at_lte,
             ppl_ids: req.ppl_ids,
             only_debug_jobs: req.only_debug_jobs,
             machine_types: req.machine_types
           },
           pagination_params <- %{
             order: Order.key(req.order),
             page_size: page_size,
             page_token: req.page_token
           },
           {:ok, jobs, token} <- Lister.list_jobs(query_params, pagination_params) do
        jobs = Zebra.LegacyRepo.preload(jobs, [:task])
        jobs = Serializer.serialize_jobs(jobs)
        status = grpc_status_ok()

        Resp.new(status: status, next_page_token: token, jobs: jobs)
      else
        {:error, :invalid_page_size, msg} ->
          Resp.new(status: grpc_status_bad_param(msg))
      end
    end)
  end

  def list_debug_sessions(req, _) do
    Watchman.benchmark("internal_job_api.list.duration", fn ->
      alias Zebra.Apis.InternalJobApi.Lister, as: Lister
      alias Zebra.Apis.InternalJobApi.Serializer, as: Serializer
      alias InternalApi.ServerFarm.Job.ListDebugSessionsResponse, as: Resp
      alias InternalApi.ServerFarm.Job.ListDebugSessionsRequest.Order

      Logger.info("List Debug Sessions #{inspect(req)}")

      with {:ok, page_size} <- parse_page_size(req.page_size),
           job_states <- map_state_names(req.debug_session_states),
           debug_types <- map_debug_types(req.types),
           query_params <- %{
             org_id: req.organization_id,
             project_id: req.project_id,
             job_states: job_states,
             debug_types: debug_types,
             user_id: req.debug_user_id,
             debugged_id: req.job_id
           },
           pagination_params <- %{
             order: Order.key(req.order),
             page_size: page_size,
             page_token: req.page_token
           },
           {:ok, debug_jobs, token} <- Lister.list_debugs(query_params, pagination_params) do
        debugs = Serializer.serialize_debugs(debug_jobs)
        status = grpc_status_ok()

        Resp.new(status: status, next_page_token: token, debug_sessions: debugs)
      else
        {:error, :invalid_page_size, msg} -> Resp.new(status: grpc_status_bad_param(msg))
      end
    end)
  end

  def count(req, _) do
    Watchman.benchmark("internal_job_api.count.duration", fn ->
      alias InternalApi.ServerFarm.Job.CountResponse, as: Resp
      import Ecto.Query

      Logger.info("Count #{inspect(req)}")

      job_states = map_state_names(req.job_states)
      finished_at_gte = map_timestamp_to_ecto(req.finished_at_gte.seconds)
      finished_at_lte = map_timestamp_to_ecto(req.finished_at_lte.seconds + 1)

      query =
        Zebra.Models.Job
        |> where([j], j.aasm_state in ^job_states)
        |> where([j], j.finished_at >= ^finished_at_gte)
        |> where([j], j.finished_at < ^finished_at_lte)

      count = Zebra.LegacyRepo.aggregate(query, :count, :id)

      Resp.new(status: grpc_status_ok(), count: count)
    end)
  end

  def count_by_state(req, _) do
    Watchman.benchmark("internal_job_api.count_by_state.duration", fn ->
      alias InternalApi.ServerFarm.Job.CountByStateResponse

      Logger.info("CountByState: #{inspect(req)}")

      CountByStateResponse.new(
        counts: by_state(map_state_names(req.states), req.org_id, req.agent_type)
      )
    end)
  end

  defp by_state([], _, _), do: []

  defp by_state(states, org_id, agent_type) do
    alias InternalApi.ServerFarm.Job.CountByStateResponse.CountByState
    import Ecto.Query

    # Counting jobs in "finished" state is very performance heavy, so we don't allow it here
    states = Enum.filter(states, fn state -> state != "finished" end)

    initial_counts =
      Enum.reduce(states, %{}, fn state, counts ->
        Map.put(counts, state, 0)
      end)

    from(j in Zebra.Models.Job,
      where: j.aasm_state in ^states,
      where: j.organization_id == ^org_id,
      where: j.machine_type == ^agent_type,
      group_by: j.aasm_state,
      select: {j.aasm_state, fragment("count(*)")}
    )
    |> Zebra.LegacyRepo.all()
    |> Enum.into(initial_counts)
    |> Enum.reduce(%{}, fn
      {"scheduled", count}, acc ->
        Map.update(acc, "scheduled", count, &(&1 + count))

      {"waiting-for-agent", count}, acc ->
        Map.update(acc, "scheduled", count, &(&1 + count))

      {state, count}, acc ->
        Map.put(acc, state, count)
    end)
    |> Enum.map(fn {state, count} ->
      CountByState.new(state: map_state_value(state), count: count)
    end)
  end

  def describe(req, _) do
    Watchman.benchmark("internal_job_api.describe.duration", fn ->
      alias Zebra.Apis.InternalJobApi.Serializer, as: Serializer
      alias InternalApi.ServerFarm.Job.DescribeResponse, as: Resp
      alias Zebra.Models.Job

      Logger.info("Describe #{inspect(req)}")

      case Job.find(req.job_id) do
        {:ok, job} ->
          job = Serializer.serialize_job(job)

          Resp.new(status: grpc_status_ok(), job: job)

        {:error, :not_found} ->
          msg = "Job with id #{req.job_id} not found"

          Resp.new(status: grpc_status_bad_param(msg))
      end
    end)
  end

  def stop(req, _call) do
    Watchman.benchmark("internal_job_api.stop.duration", fn ->
      user_id = req.requester_id

      job_id = req.job_id

      Logger.info("Stopping job with id: #{job_id} requester_id: #{user_id}")

      case fetch_user_job(job_id) do
        {:ok, job} ->
          {:ok, _} = Zebra.Workers.JobStopper.request_stop_async(job)

          %{status: %{code: :OK, message: "Job will be stopped."}}
          |> Util.Proto.deep_new!(StopResponse)

        {:error, :not_found, message} ->
          %{status: %{code: :BAD_PARAM, message: message}}
          |> Util.Proto.deep_new!(StopResponse)
      end
    end)
  end

  def total_execution_time(req, _call) do
    alias InternalApi.ServerFarm.Job.TotalExecutionTimeResponse, as: Response
    alias Zebra.Apis.InternalJobApi.TotalExecutionTime

    org_id = req.org_id

    Watchman.benchmark("internal_job_api.total_execution_time.duration", fn ->
      Logger.info("Calculating execution time for org_id: #{org_id}")

      case TotalExecutionTime.calculate(org_id) do
        {:ok, total} ->
          Response.new(total_duration_in_secs: round(total))

        e ->
          Logger.info("TotalExecutionTime error: #{inspect(e)}")
          raise "Can't calculate total execution time for #{org_id}."
      end
    end)
  end

  def get_agent_payload(req, _call) do
    alias Zebra.Models.Job

    Watchman.benchmark("internal_job_api.get_agent_payload.duration", fn ->
      Logger.info("GetJobPayload #{inspect(req)}")

      case Job.find(req.job_id) do
        {:ok, job} ->
          # Now that the self-hosted agent will receive the job request, we can sanitize it.
          Task.start(
            Zebra.Models.Job,
            :sanitize_job_request,
            [job.id]
          )

          InternalApi.ServerFarm.Job.GetAgentPayloadResponse.new(
            payload: Poison.encode!(job.request)
          )

        {:error, :not_found} ->
          raise GRPC.RPCError, status: :not_found, message: "Not found"
      end
    end)
  end

  def can_debug(req, _call) do
    alias Zebra.Apis.DebugPermissions
    alias InternalApi.ServerFarm.Job.CanDebugResponse, as: Response

    Watchman.benchmark("internal_job_api.can_debug.duration", fn ->
      Logger.info("CanDebug #{inspect(req)}")

      case fetch_user_job(req.job_id) do
        {:ok, job} ->
          case DebugPermissions.check(job.organization_id, job, :debug) do
            {:ok, true} ->
              Response.new(allowed: true)

            {:error, :permission_denied, message} ->
              Response.new(allowed: false, message: message)

            {:error, :internal, message} ->
              raise GRPC.RPCError, status: :internal, message: message
          end

        {:error, :not_found, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end)
  end

  def can_attach(req, _call) do
    alias Zebra.Apis.DebugPermissions
    alias InternalApi.ServerFarm.Job.CanAttachResponse, as: Response
    alias Zebra.Apis.DeploymentTargets

    Watchman.benchmark("internal_job_api.can_attach.duration", fn ->
      Logger.info("CanAttach #{inspect(req)}")

      with {:ok, job} <- fetch_user_job(req.job_id),
           {:ok, true} <- DebugPermissions.check(job.organization_id, job, :attach),
           {:ok, true} <- DeploymentTargets.can_run?(job, req.user_id) do
        Response.new(allowed: true)
      else
        {:error, :not_found, message} ->
          raise GRPC.RPCError, status: :not_found, message: message

        {:error, :internal, message} ->
          raise GRPC.RPCError, status: :internal, message: message

        {:error, :permission_denied, message} ->
          Response.new(allowed: false, message: message)
      end
    end)
  end

  defp fetch_user_job(job_id) do
    import Ecto.Query
    alias Zebra.Models.Job

    job = Job |> where([j], j.id == ^job_id) |> Zebra.LegacyRepo.one()

    if job do
      {:ok, job}
    else
      {:error, :not_found, "Job with id: '#{job_id}' not found"}
    end
  end

  def map_state_names(states) do
    alias InternalApi.ServerFarm.Job.Job.State

    states
    |> Enum.map(fn s ->
      case State.key(s) do
        :PENDING -> ["pending"]
        :ENQUEUED -> ["enqueued"]
        :SCHEDULED -> ["scheduled", "waiting-for-agent"]
        :STARTED -> ["started"]
        :FINISHED -> ["finished"]
      end
    end)
    |> List.flatten()
  end

  def map_state_value("pending"), do: State.value(:PENDING)
  def map_state_value("enqueued"), do: State.value(:ENQUEUED)
  def map_state_value("scheduled"), do: State.value(:SCHEDULED)
  def map_state_value("started"), do: State.value(:STARTED)

  def map_debug_types(types) do
    alias InternalApi.ServerFarm.Job.DebugSessionType

    types
    |> Enum.map(fn t ->
      case DebugSessionType.key(t) do
        :PROJECT -> "project"
        :JOB -> "job"
      end
    end)
  end

  def map_timestamp_to_ecto(timestamp) do
    DateTime.from_unix!(timestamp) |> DateTime.to_naive()
  end

  def grpc_status_ok do
    code = InternalApi.ResponseStatus.Code.value(:OK)
    InternalApi.ResponseStatus.new(code: code)
  end

  def grpc_status_bad_param(msg) do
    code = InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
    InternalApi.ResponseStatus.new(code: code, message: msg)
  end

  def parse_page_size(page_size) do
    max = 1000

    cond do
      page_size > max ->
        msg = "Page size must be between 1 and #{max}. Got #{page_size}."
        {:error, :invalid_page_size, msg}

      # default value
      page_size == 0 ->
        {:ok, max}

      true ->
        {:ok, page_size}
    end
  end
end
