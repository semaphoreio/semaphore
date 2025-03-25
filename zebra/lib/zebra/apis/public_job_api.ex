defmodule Zebra.Apis.PublicJobApi do
  require Logger

  use GRPC.Server, service: Semaphore.Jobs.V1alpha.JobsApi.Service
  use Sentry.Grpc, service: Semaphore.Jobs.V1alpha.JobsApi.Service

  alias Zebra.Models.Debug
  alias Zebra.Models.Job
  alias Zebra.Workers.JobRequestFactory.{Project, Secrets}
  alias Zebra.Apis.PublicJobApi.{Lister, Getter, Headers, Auth, Serializer}
  alias Zebra.Apis.DebugPermissions

  def list_jobs(req, call) do
    Watchman.benchmark("public_job_api.list_jobs.duration", fn ->
      alias Semaphore.Jobs.V1alpha.ListJobsResponse, as: Response

      {org_id, user_id} = Headers.extract_org_id_and_user_id(call)

      Logger.info("Listing #{org_id} #{user_id} #{inspect(req)}")

      with {:ok, page_size} <- Lister.extract_page_size(req),
           {:ok, project_ids} <- Auth.list_accessible_projects(org_id, user_id),
           {:ok, jobs, next_page_token} <- Lister.list_jobs(org_id, page_size, project_ids, req) do
        jobs = jobs |> Enum.map(&Serializer.serialize/1)

        Response.new(jobs: jobs, next_page_token: next_page_token)
      else
        {:error, :precondition_failed, message} ->
          raise GRPC.RPCError, status: :invalid_argument, message: message
      end
    end)
  end

  def get_job(req, call) do
    Watchman.benchmark("public_job_api.get_job.duration", fn ->
      {org_id, user_id} = Headers.extract_org_id_and_user_id(call)
      Logger.info("Describing #{org_id} #{user_id} #{req.job_id}")

      Getter.get_job(org_id, user_id, req.job_id)
    end)
  end

  def get_job_debug_ssh_key(req, call) do
    Watchman.benchmark("public_job_api.get_job_debug_ssh_key.duration", fn ->
      {org_id, user_id} = Headers.extract_org_id_and_user_id(call)
      Logger.info("Getting debug SSH key #{org_id} #{user_id} #{req.job_id}")

      with {:ok, job} <- Getter.find_job_in_db(org_id, user_id, req.job_id),
           {:ok, true} <- can_use_secrets?(org_id, Job.decode_spec(job.spec), operation(job)),
           {:ok, true} <- can_get_job_ssh_key?(org_id, job) do
        Getter.get_job_debug_ssh_key(job)
      else
        {:error, :permission_denied, message} ->
          raise GRPC.RPCError, status: :permission_denied, message: message

        {:error, :not_found, message} ->
          raise GRPC.RPCError, status: :not_found, message: message

        {:error, :invalid_id, message} ->
          raise GRPC.RPCError, status: :invalid_argument, message: message

        {:error, :internal, message} ->
          raise GRPC.RPCError, status: :internal, message: message
      end
    end)
  end

  def create_job(req, call) do
    Watchman.benchmark("public_job_api.create_job.duration", fn ->
      alias Zebra.Models.Job

      # We don't allow jobs to be created this way
      # for self-hosted agent types.
      if Job.self_hosted?(req.spec.agent.machine.type) do
        raise GRPC.RPCError,
          status: :invalid_argument,
          message: "Self-hosted agent type is not allowed"
      end

      {org_id, user_id} = Headers.extract_org_id_and_user_id(call)

      project_id = req.spec.project_id

      Logger.info("Creating org: #{org_id} user: #{user_id} project: #{project_id}")
      Logger.info("Request: #{inspect(req)}")

      job_params = [
        organization_id: org_id,
        project_id: project_id,
        index: 0,
        machine_type: req.spec.agent.machine.type,
        machine_os_image: req.spec.agent.machine.os_image,
        name: req.metadata.name,
        spec: req.spec
      ]

      with {:ok, true} <- can_start_pipeline?(org_id, user_id, project_id),
           {:ok, true} <- can_access_project?(org_id, user_id, project_id),
           {:ok, true} <- can_use_secrets?(org_id, req.spec, :debug),
           {:ok, job} <- Job.create(job_params) do
        Serializer.serialize(job)
      else
        {:error, :permission_denied, message} ->
          raise GRPC.RPCError, status: :permission_denied, message: message

        {:error, :not_found, message} ->
          raise GRPC.RPCError, status: :not_found, message: message

        {:error, :invalid_argument, message} ->
          raise GRPC.RPCError, status: :invalid_argument, message: message

        {:error, :internal, message} ->
          raise GRPC.RPCError, status: :internal, message: message

        {:error, message} ->
          raise GRPC.RPCError, status: :invalid_argument, message: message
      end
    end)
  end

  def create_debug_project(req, call) do
    Watchman.benchmark("public_job_api.create_debug_project.duration", fn ->
      alias Zebra.Models.Job
      alias Zebra.Models.Debug, as: DebugModel
      alias Zebra.Apis.PublicJobApi.Debug, as: DebugParams
      alias Zebra.Workers.JobRequestFactory.Project

      {org_id, user_id} = Headers.extract_org_id_and_user_id(call)

      project_id_or_name = req.project_id_or_name

      Logger.info(
        "Creating debug project org: #{org_id} user: #{user_id} project: #{project_id_or_name}"
      )

      Zebra.LegacyRepo.transaction(fn ->
        with {:ok, project} <- Project.find_by_id_or_name(project_id_or_name, org_id, user_id),
             {:ok, true} <- can_create_debug_project?(org_id, project),
             {:ok, true} <- can_start_pipeline?(org_id, user_id, project.id),
             job_params <-
               DebugParams.make_debug_project_params(
                 org_id,
                 project,
                 req.machine_type,
                 req.duration
               ),
             {:ok, debug_job} <- Job.create(job_params),
             {:ok, _debug} <-
               DebugModel.create(debug_job.id, DebugModel.type_project(), project.id, user_id) do
          Serializer.serialize(debug_job)
        else
          {:error, :permission_denied, message} ->
            raise GRPC.RPCError, status: :permission_denied, message: message

          {:error, :not_found, message} ->
            raise GRPC.RPCError, status: :not_found, message: message

          {:error, :invalid_argument, message} ->
            raise GRPC.RPCError, status: :invalid_argument, message: message

          {:error, :internal, message} ->
            raise GRPC.RPCError, status: :internal, message: message

          {:error, :communication_error} ->
            raise GRPC.RPCError, status: :internal, message: "Error checking org permissions"
        end
      end)
      |> elem(1)
    end)
  end

  def create_debug_job(req, call) do
    Watchman.benchmark("public_job_api.create_debug_job.duration", fn ->
      alias Zebra.Models.Job
      alias Zebra.Models.Debug, as: DebugModel
      alias Zebra.Apis.PublicJobApi.Debug, as: DebugParams
      alias Zebra.Apis.DeploymentTargets

      {org_id, user_id} = Headers.extract_org_id_and_user_id(call)

      job_id = req.job_id

      Logger.info("Creating debug org: #{org_id} user: #{user_id} job: #{job_id}")

      Zebra.LegacyRepo.transaction(fn ->
        with {:ok, job} <- fetch_user_job(job_id, org_id, user_id),
             {:ok, true} <- can_start_pipeline?(org_id, user_id, job.project_id),
             {:ok, true} <- can_create_debug_job?(org_id, job),
             {:ok, true} <- DeploymentTargets.can_run?(job, user_id),
             {:ok, true} <- can_use_secrets?(org_id, Job.decode_spec(job.spec), :debug),
             {:ok, job_params} <- DebugParams.debug_job_params(job, req.duration),
             {:ok, debug_job} <- Job.create(job_params),
             {:ok, _debug} <-
               DebugModel.create(debug_job.id, DebugModel.type_job(), job_id, user_id) do
          Serializer.serialize(debug_job)
        else
          {:error, :permission_denied, message} ->
            raise GRPC.RPCError, status: :permission_denied, message: message

          {:error, :not_found, message} ->
            raise GRPC.RPCError, status: :not_found, message: message

          {:error, :invalid_argument, message} ->
            raise GRPC.RPCError, status: :invalid_argument, message: message

          {:error, :internal, message} ->
            raise GRPC.RPCError, status: :internal, message: message
        end
      end)
      |> elem(1)
    end)
  end

  def stop_job(req, call) do
    Watchman.benchmark("public_job_api.stop_job.duration", fn ->
      import Ecto.Query

      {org_id, user_id} = Headers.extract_org_id_and_user_id(call)

      job_id = req.job_id

      Logger.info("Stopping org_id: #{org_id} user_id: #{user_id} job_id: #{job_id}")

      case fetch_user_job(job_id, org_id, user_id) do
        {:ok, job} ->
          {:ok, _} = Zebra.Workers.JobStopper.request_stop_async(job)

          Semaphore.Jobs.V1alpha.Empty.new()

        {:error, :not_found, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end)
  end

  defp can_start_pipeline?(org_id, user_id, project_id) do
    case Auth.can_start_pipeline?(org_id, user_id, project_id) do
      {:ok, true} ->
        {:ok, true}

      {:ok, false} ->
        {:error, :permission_denied, "You are not allowed to run pipelines on this project"}

      {:error, message} ->
        {:error, :internal, message}
    end
  end

  defp can_use_secrets?(org_id, spec, :debug_empty), do: can_use_secrets?(org_id, spec, :debug)

  defp can_use_secrets?(org_id, spec, op) do
    case Secrets.validate_job_secrets(org_id, spec, op) do
      {:ok, true} ->
        {:ok, true}

      {:ok, false} ->
        {:error, :permission_denied, "Some secrets used in this job are blocking this operation"}

      {:error, message} ->
        {:error, :internal, message}
    end
  end

  defp can_create_debug_job?(org_id, job) do
    if job.spec["restricted_job"] do
      {:error, :permission_denied, "The debug session is blocked for this job."}
    else
      DebugPermissions.check(org_id, job, :debug)
    end
  end

  defp can_create_debug_project?(org_id, project) do
    DebugPermissions.check_project(org_id, project, :debug_empty)
  end

  defp can_get_job_ssh_key?(org_id, job) do
    if Job.self_hosted?(job.machine_type) do
      {:error, :permission_denied, "SSH keys are not available for self-hosted jobs"}
    else
      if job.spec["restricted_job"] do
        {:error, :permission_denied, "Attaching to this job is blocked."}
      else
        operation = operation(job)

        DebugPermissions.check(org_id, job, operation)
      end
    end
  end

  defp can_access_project?(org_id, user_id, project_id) do
    {:ok, project_ids} = Auth.list_accessible_projects(org_id, user_id)

    if Enum.member?(project_ids, project_id) do
      {:ok, true}
    else
      {:error, :not_found, "Project #{project_id} not found"}
    end
  end

  defp operation(job) do
    case job.build_id do
      nil ->
        case Debug.find_by_job_id(job.id) do
          {:ok, _debug} -> :debug
          _ -> :debug_empty
        end

      _ ->
        :attach
    end
  end

  defp fetch_user_job(job_id, org_id, user_id) do
    import Ecto.Query
    alias Zebra.Models.Job

    {:ok, project_ids} = Auth.list_accessible_projects(org_id, user_id)

    job =
      Job
      |> where([j], j.organization_id == ^org_id)
      |> where([j], j.project_id in ^project_ids)
      |> where([j], j.id == ^job_id)
      |> Zebra.LegacyRepo.one()

    if job do
      {:ok, job}
    else
      {:error, :not_found, "Job #{job_id} not found"}
    end
  end
end
