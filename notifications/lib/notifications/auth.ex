defmodule Notifications.Auth do
  require Logger

  alias InternalApi.RBAC.RBAC.Stub
  alias InternalApi.RBAC.ListUserPermissionsRequest, as: Request

  def can_view?(user_id, org_id) do
    authorize(user_id, org_id, "organization.notifications.view")
  end

  def can_manage?(user_id, org_id) do
    authorize(user_id, org_id, "organization.notifications.manage")
  end

  defp authorize(user_id, org_id, permission) do
    req = Request.new(user_id: user_id, org_id: org_id)
    endpoint = Application.fetch_env!(:notifications, :rbac_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    case Stub.list_user_permissions(channel, req, timeout: 30_000) do
      {:ok, res} ->
        if Enum.member?(res.permissions, permission) do
          {:ok, :authorized}
        else
          {:error, :permission_denied}
        end

      {:error, error} ->
        Logger.info(
          "Error checking permissions for user=#{user_id}, org=#{org_id}: #{inspect(error)}"
        )

        {:error, :permission_denied}
    end
  end
end
