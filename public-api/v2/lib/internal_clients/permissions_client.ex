defmodule InternalClients.Permissions do
  require Logger

  @moduledoc """
    Function that checks which permissions user has within the organization and/or project.

    Arguments:
      - user_id [required]
      - org_id [required]
      - project_id [required if at least one permission is project-scoped]
      - permission [required] - either one single permission (string), or a list of permissions

    Return value:
      - If one single permission is passed, than return value is true or false.
      - If list of permissions is passed, than a map is returned where each permission is
      paired with true/false value
  """
  def has?(user_id, org_id, permission), do: has?(user_id, org_id, "", permission)

  def has?(user_id, _org_id, _project_id, permissions) when user_id in [nil, ""] do
    Logger.info("[Permissions] has? called with user_id #{inspect(user_id)}")

    if is_list(permissions) do
      generate_all_false_response(permissions)
    else
      false
    end
  end

  def has?(user_id, org_id, project_id, permissions) when not is_list(permissions) do
    has?(user_id, org_id, project_id, [permissions])
    |> Map.values()
    |> List.first()
  end

  def has?(user_id, org_id, project_id, permissions) do
    Watchman.benchmark("has_permissions.duration", fn ->
      if Application.fetch_env!(:public_api, :use_rbac_api) do
        res = with_rbac_api(user_id, org_id, project_id, permissions)

        Logger.debug(
          "RBAC API check for user=#{user_id}, org=#{org_id}, project=#{project_id}: #{inspect(res)}"
        )

        res
      else
        res = with_permission_patrol(user_id, org_id, project_id, permissions)

        Logger.debug(
          "Permission Patrol check for user=#{user_id}, org=#{org_id}, project=#{project_id}: #{inspect(res)}"
        )

        res
      end
    end)
  rescue
    e ->
      Logger.error(
        "[Permissions] Unexpected error: #{inspect(e)} \n" <>
          "User_id: #{inspect(user_id)}, org_id: #{inspect(org_id)}, project_id: #{inspect(project_id)}, permissions: #{inspect(permissions)}"
      )

      Watchman.increment("has_permissions.failure")
      generate_all_false_response(permissions)
  end

  ###
  ### Helper functions
  ###

  defp with_rbac_api(user_id, org_id, project_id, permissions) do
    alias InternalApi.RBAC.ListUserPermissionsRequest
    alias InternalApi.RBAC.RBAC.Stub

    request =
      %ListUserPermissionsRequest{
        user_id: user_id,
        org_id: org_id,
        project_id: project_id
      }

    rbac_channel()
    |> Stub.list_user_permissions(request, timeout: rbac_grpc_timeout())
    |> case do
      {:ok, response} ->
        #
        # If the list of permissions wanted is empty,
        # it means we want to list all the permissions the user has,
        # which is what the RBAC API gives us anyway, so we just transform the response.
        # Otherwise, we check if the permissions wanted are in the list
        # of permissions returned by the RBAC API.
        #
        if Enum.empty?(permissions) do
          Enum.reduce(response.permissions, %{}, fn permission, acc ->
            Map.put(acc, permission, true)
          end)
        else
          Enum.reduce(permissions, %{}, fn permission, acc ->
            Map.put(acc, permission, Enum.member?(response.permissions, permission))
          end)
        end

      {:error, error} ->
        raise(error)
    end
  end

  defp with_permission_patrol(user_id, org_id, project_id, permissions) do
    req = %InternalApi.PermissionPatrol.HasPermissionsRequest{
      user_id: user_id,
      org_id: org_id,
      project_id: project_id,
      permissions: permissions
    }

    permission_patrol_channel()
    |> InternalApi.PermissionPatrol.PermissionPatrol.Stub.has_permissions(req,
      timeout: permission_patrol_timeout()
    )
    |> case do
      {:ok, resp} ->
        resp.has_permissions

      {:error, error} ->
        raise(error)
    end
  end

  defp generate_all_false_response(permissions) do
    Enum.reduce(permissions, %{}, fn permission, acc ->
      Map.put(acc, permission, false)
    end)
  end

  def permission_patrol_channel do
    {:ok, ch} = GRPC.Stub.connect(permission_patrol_grpc_endpoint())
    ch
  end

  defp permission_patrol_timeout do
    Application.fetch_env!(:public_api, :permission_patrol_timeout)
  end

  defp permission_patrol_grpc_endpoint do
    Application.fetch_env!(:public_api, :permission_patrol_grpc_endpoint)
  end

  def rbac_channel do
    {:ok, ch} = GRPC.Stub.connect(rbac_grpc_endpoint())
    ch
  end

  def rbac_grpc_timeout do
    Application.fetch_env!(:public_api, :rbac_grpc_timeout)
  end

  defp rbac_grpc_endpoint do
    Application.fetch_env!(:public_api, :rbac_api_grpc_endpoint)
  end
end
