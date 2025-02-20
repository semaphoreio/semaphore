defmodule Secrethub.Auth do
  alias InternalApi.RBAC.ListUserPermissionsRequest
  alias InternalApi.RBAC.RBAC.Stub

  def can_manage?("", _), do: {:error, :permission_denied}
  def can_manage?(nil, _), do: {:error, :permission_denied}
  def can_manage?(_, ""), do: {:error, :permission_denied}
  def can_manage?(_, nil), do: {:error, :permission_denied}

  def can_manage?(org_id, user_id) do
    is_authorized?(org_id, user_id, "", "organization.secrets.manage")
  end

  def can_manage?("", _, _), do: {:error, :permission_denied}
  def can_manage?(nil, _, _), do: {:error, :permission_denied}
  def can_manage?(_, "", _), do: {:error, :permission_denied}
  def can_manage?(_, nil, _), do: {:error, :permission_denied}
  def can_manage?(_, _, ""), do: {:error, :permission_denied}
  def can_manage?(_, _, nil), do: {:error, :permission_denied}

  def can_manage?(org_id, user_id, project_id) do
    is_authorized?(org_id, user_id, project_id, "project.secrets.manage")
  end

  def can_manage_settings?("", _), do: {:error, :permission_denied}
  def can_manage_settings?(nil, _), do: {:error, :permission_denied}
  def can_manage_settings?(_, ""), do: {:error, :permission_denied}
  def can_manage_settings?(_, nil), do: {:error, :permission_denied}

  def can_manage_settings?(org_id, user_id) do
    is_authorized?(org_id, user_id, "", "organization.secrets_policy_settings.manage")
  end

  defp is_authorized?(org_id, user_id, project_id, permission) do
    req =
      ListUserPermissionsRequest.new(
        user_id: user_id,
        org_id: org_id,
        project_id: project_id
      )

    case Cachex.fetch(:auth_cache, request_id(req, permission), fn _id ->
           _is_authorized?(req, permission)
         end) do
      {:ok, value} ->
        value

      {:commit, value} ->
        Cachex.expire(:auth_cache, request_id(req, permission), :timer.minutes(5))

        value

      e ->
        e
    end
  end

  defp _is_authorized?(req, permission) do
    with {:ok, channel} <-
           GRPC.Stub.connect(Application.fetch_env!(:secrethub, :rbac_grpc_endpoint)),
         {:ok, res} <- Stub.list_user_permissions(channel, req, timeout: 30_000) do
      if Enum.member?(res.permissions, permission) do
        {:commit, {:ok, :authorized}}
      else
        {:commit, {:error, :permission_denied}}
      end
    else
      e -> e
    end
  end

  defp request_id(req, permission) do
    string = req |> Poison.encode!()

    :crypto.hash(:sha256, string <> permission)
    |> Base.encode16()
    |> String.downcase()
  end
end
