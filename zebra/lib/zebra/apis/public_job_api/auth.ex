defmodule Zebra.Apis.PublicJobApi.Auth do
  require Logger
  alias InternalApi.RBAC.RBAC.Stub

  def list_accessible_projects(org_id, user_id) do
    endpoint = Application.fetch_env!(:zebra, :rbac_endpoint)
    timeout = Application.fetch_env!(:zebra, :rbac_timeout)

    {:ok, channel} = GRPC.Stub.connect(endpoint)
    req = InternalApi.RBAC.ListAccessibleProjectsRequest.new(user_id: user_id, org_id: org_id)

    case Stub.list_accessible_projects(channel, req, timeout: timeout) do
      {:ok, resp} ->
        {:ok, resp.project_ids}

      e ->
        Logger.error("Error #{inspect(e)} while fetching projects for #{inspect(req)}")
        {:ok, []}
    end
  end

  @start_pipeline_permission "project.job.rerun"
  def can_start_pipeline?(org_id, user_id, project_id) do
    endpoint = Application.fetch_env!(:zebra, :rbac_endpoint)
    timeout = Application.fetch_env!(:zebra, :rbac_timeout)

    {:ok, channel} = GRPC.Stub.connect(endpoint)

    req =
      InternalApi.RBAC.ListUserPermissionsRequest.new(
        org_id: org_id,
        user_id: user_id,
        project_id: project_id
      )

    case Stub.list_user_permissions(channel, req, timeout: timeout) do
      {:ok, resp} ->
        {:ok, @start_pipeline_permission in resp.permissions}

      e ->
        Logger.error("Error #{inspect(e)} while listing permissions for #{inspect(req)}")

        {:error,
         "Something went wrong. Please try again later. If the issue still persists contact support."}
    end
  end
end
