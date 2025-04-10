defmodule PipelinesAPI.RoleBindings.Delete do
  @moduledoc """
  Plug deletes a role binding (removes role from the subject).
  """
  use Plug.Builder
  require Logger

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias PipelinesAPI.Pipelines.Common
  alias PipelinesAPI.Util.VerifyData, as: VD
  alias PipelinesAPI.UserApiClient

  plug(:put_assigns)
  plug(:authorize)
  plug(:fetch_user_to_be_deleted)
  plug(:delete)

  def delete(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["rbac_delete"], fn ->
      requester_id = conn.assigns.requester_id
      org_id = conn.assigns.org_id
      user_id = conn.assigns.user_id

      Logger.info("Removing role: #{user_id} - #{org_id}. Action performed by #{requester_id}")

      resp =
        RBACClient.retract_role(%{requester_id: requester_id, user_id: user_id, org_id: org_id})

      resp |> Common.respond(conn)
    end)
  end

  defp put_assigns(conn, _opts) do
    requester_id = conn |> Plug.Conn.get_req_header("x-semaphore-user-id") |> List.first()
    org_id = conn |> Plug.Conn.get_req_header("x-semaphore-org-id") |> List.first()

    cond do
      is_nil(requester_id) ->
        Common.respond({:error, {:user, "Missing user id in request header"}}, conn)

      not VD.is_valid_uuid?(requester_id) ->
        Common.respond({:error, {:user, "Invalid user id format"}}, conn)

      is_nil(org_id) ->
        Common.respond({:error, {:user, "Missing organization id in request header"}}, conn)

      not VD.is_valid_uuid?(org_id) ->
        Common.respond({:error, {:user, "Invalid organization id format"}}, conn)

      true ->
        conn
        |> Plug.Conn.assign(:requester_id, requester_id)
        |> Plug.Conn.assign(:org_id, org_id)
    end
  end

  defp authorize(conn, _opts) do
    requester_id = conn.assigns.requester_id
    org_id = conn.assigns.org_id

    params = %{user_id: requester_id, org_id: org_id}

    case RBACClient.list_user_permissions(params) do
      {:ok, permissions} ->
        if Enum.member?(permissions, "organization.people.manage") do
          conn |> Plug.Conn.assign(:permissions, permissions)
        else
          Common.respond({:error, {:user, "Permission denied"}}, conn)
        end

      error ->
        Logger.error("Error when listing permissions: #{inspect(error)}")
        Common.respond({:error, {:internal, "Internal error"}}, conn)
    end
  end

  defp fetch_user_to_be_deleted(conn, _opts) do
    user_id = conn.query_params["user_id"]
    email = conn.query_params["email"]

    cond do
      not is_nil(user_id) ->
        lookup_user_by_id(conn, user_id)

      not is_nil(email) ->
        lookup_user_by_email(conn, email)

      true ->
        Common.respond({:error, {:user, "Missing user_id or email in query parameters"}}, conn)
    end
  end

  defp lookup_user_by_id(conn, user_id) do
    case UserApiClient.describe_many([user_id]) do
      {:ok, %{users: users}} when is_list(users) and length(users) > 0 ->
        [user | _] = users
        conn |> Plug.Conn.assign(:user_id, user.id)

      {:ok, _} ->
        Logger.info("User with id #{user_id} not found")
        Common.respond({:error, {:user, "User with id #{user_id} not found"}}, conn)

      error ->
        Logger.error("Error when fetching user by ID: #{inspect(error)}")
        Common.respond({:error, {:internal, "Internal error"}}, conn)
    end
  end

  defp lookup_user_by_email(conn, email) do
    case UserApiClient.describe_by_email(email) do
      {:ok, user} ->
        conn |> Plug.Conn.assign(:user_id, user.id)

      {:error, :not_found} ->
        Logger.info("User with email #{email} not found")
        Common.respond({:error, {:user, "User with email #{email} not found"}}, conn)

      error ->
        Logger.error("Error when fetching user by email: #{inspect(error)}")
        Common.respond({:error, {:internal, "Internal error"}}, conn)
    end
  end
end
