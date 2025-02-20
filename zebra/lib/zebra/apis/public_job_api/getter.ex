defmodule Zebra.Apis.PublicJobApi.Getter do
  require Logger

  alias Zebra.Models.Job
  alias Zebra.Apis.PublicJobApi.{Auth, Serializer}

  import Ecto.Query

  def get_job(org_id, user_id, job_id) do
    case find_job_in_db(org_id, user_id, job_id) do
      {:ok, job} ->
        Serializer.serialize(job)

      {:error, :not_found, message} ->
        raise GRPC.RPCError, status: :not_found, message: message

      {:error, :invalid_id, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message
    end
  end

  def get_job_debug_ssh_key(job) do
    alias Semaphore.Jobs.V1alpha.JobDebugSSHKey

    if Job.started?(job) do
      JobDebugSSHKey.new(key: job.private_ssh_key)
    else
      msg = "Job's debug SSH is only available while the job is running"
      raise GRPC.RPCError, status: :failed_precondition, message: msg
    end
  end

  def find_job_in_db(org_id, user_id, job_id) do
    case Ecto.UUID.cast(job_id) do
      {:ok, job_id} ->
        {:ok, project_ids} = Auth.list_accessible_projects(org_id, user_id)

        case Zebra.Models.Job
             |> where([j], j.organization_id == ^org_id)
             |> where([j], j.project_id in ^project_ids)
             |> where([j], j.id == ^job_id)
             |> Zebra.LegacyRepo.one() do
          nil -> {:error, :not_found, "Job #{job_id} not found"}
          job -> {:ok, job}
        end

      :error ->
        {:error, :invalid_id, "Job id #{job_id} is invalid"}
    end
  end
end
