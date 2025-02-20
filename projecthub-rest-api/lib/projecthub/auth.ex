defmodule Projecthub.Auth do
  require Logger

  alias InternalApi.RBAC.RBAC.Stub
  alias InternalApi.RBAC.ListAccessibleProjectsRequest
  alias InternalApi.RBAC.ListUserPermissionsRequest

  def has_permissions?(org_id, user_id, permission) do
    has_permissions?(org_id, user_id, "", permission)
  end

  def has_permissions?(org_id, user_id, project_id, permissions) when not is_list(permissions) do
    has_permissions?(org_id, user_id, project_id, [permissions])
  end

  def has_permissions?(org_id, user_id, project_id, permissions) do
    req =
      ListUserPermissionsRequest.new(
        org_id: org_id,
        user_id: user_id,
        project_id: project_id
      )

    case Cachex.fetch(:auth_cache, request_id(req, permissions), fn _id ->
           _has_permissions?(req, permissions)
         end) do
      {:ok, value} ->
        value

      {:commit, value} ->
        Cachex.expire(:auth_cache, request_id(req, permissions), :timer.minutes(5))

        value

      e ->
        e
    end
  end

  defp _has_permissions?(req, permissions) do
    endpoint = Application.fetch_env!(:projecthub, :rbac_grpc_endpoint)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, res} <- Stub.list_user_permissions(channel, req, timeout: 30_000) do
      {:commit, Enum.all?(permissions, fn p -> Enum.member?(res.permissions, p) end)}
    else
      e ->
        e
    end
  end

  defp request_id(req, permissions) do
    string = req |> Poison.encode!()

    :crypto.hash(:sha256, string <> Enum.join(permissions, ","))
    |> Base.encode16()
    |> String.downcase()
  end

  def list_accessible_projects(org_id, user_id) do
    request =
      ListAccessibleProjectsRequest.new(
        user_id: user_id,
        org_id: org_id
      )

    endpoint = Application.fetch_env!(:projecthub, :rbac_grpc_endpoint)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- Stub.list_accessible_projects(channel, request, timeout: 30_000) do
      {:ok, response.project_ids}
    else
      e ->
        Logger.error(
          "Error listing accessible projects for org=#{org_id}, user=#{user_id}: #{inspect(e)}"
        )

        e
    end
  end

  def filter_projects(projects, org_id, user_id) do
    case list_accessible_projects(org_id, user_id) do
      {:ok, accessible_project_ids} ->
        Enum.filter(projects, fn project ->
          Enum.member?(accessible_project_ids, project.metadata.id)
        end)

      _e ->
        []
    end
  end
end
