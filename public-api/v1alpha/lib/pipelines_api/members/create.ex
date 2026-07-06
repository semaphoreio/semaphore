defmodule PipelinesAPI.Members.Create do
  @moduledoc """
  Invites a human to the organization by SCM handle and optionally sets an
  initial org role.

  Two-step orchestration:
    1. Guard.InviteCollaborators adds the person (always as "Member").
    2. Resolve their Semaphore user_id via UserService.
    3. If a role_id was requested and the user_id is resolvable, upgrade the
       role via RBAC.AssignRole.

  A brand-new invitee may not have a Semaphore account yet, so the user_id can
  be unresolvable at invite time. In that case we respond success with the role
  marked pending (defaulted to Member) rather than failing.
  """
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.{GuardClient, UserApiClient, RBACClient}
  alias PipelinesAPI.Audit
  alias InternalApi.User.RepositoryProvider
  alias Plug.Conn

  import PipelinesAPI.Members.Authorize, only: [authorize_manage_people: 2]

  @provider_types %{
    "github" => RepositoryProvider.Type.value(:GITHUB),
    "bitbucket" => RepositoryProvider.Type.value(:BITBUCKET),
    "gitlab" => RepositoryProvider.Type.value(:GITLAB)
  }

  plug(:authorize_manage_people)
  plug(:create_member)

  def create_member(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["members_create"], fn ->
      conn.params
      |> validate_provider()
      |> invite_and_build(conn)
      |> tap(fn result -> audit_event(result, conn) end)
      |> RespCommon.respond(conn)
    end)
  end

  # Reject an unknown provider up front with a 400 instead of letting it degrade
  # to a pending role after a real invite side effect.
  defp validate_provider(params) do
    provider = params["provider"] |> to_string() |> String.downcase()

    if Map.has_key?(@provider_types, provider) do
      {:ok, params}
    else
      {:error, {:user, "provider must be one of: github, bitbucket, gitlab"}}
    end
  end

  defp invite_and_build(error = {:error, _}, _conn), do: error

  defp invite_and_build({:ok, params}, conn) do
    params
    |> GuardClient.invite_collaborators(conn)
    |> assign_role_and_build(conn)
  end

  # Invite failed -> map the gRPC error through the standard error path.
  defp assign_role_and_build(error = {:error, _}, _conn), do: error

  defp assign_role_and_build({:ok, member}, conn) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    role_id = conn.params["role_id"]

    provider = conn.params["provider"] |> to_string() |> String.downcase()
    provider_type = Map.get(@provider_types, provider)
    handle = Map.get(member, :handle, conn.params["handle"] || "")
    uid = Map.get(member, :uid, conn.params["uid"] || "")

    case UserApiClient.describe_by_repository_provider(provider_type, handle, uid) do
      {:ok, user} ->
        apply_role(member, user.id, role_id, org_id, requester_id)

      # Person not on Semaphore yet (or user_id not resolvable) -> success,
      # role pending. Never 500 after a successful invite.
      _ ->
        {:ok,
         %{
           member: Map.put(member, :user_id, nil),
           role: role_status(role_id, false)
         }}
    end
  end

  # No role requested -> leave the default Member role.
  defp apply_role(member, user_id, nil, _org_id, _requester_id) do
    {:ok, %{member: Map.put(member, :user_id, user_id), role: role_status(nil, false)}}
  end

  defp apply_role(member, user_id, role_id, org_id, requester_id) do
    result =
      %{
        role_id: role_id,
        org_id: org_id,
        project_id: "",
        subject_id: user_id,
        requester_id: requester_id
      }
      |> RBACClient.assign_role()

    case result do
      {:ok, _} ->
        {:ok,
         %{
           member: Map.put(member, :user_id, user_id),
           role: role_status(role_id, true)
         }}

      # The invite already added the person as a Member; the role upgrade just
      # could not be applied (e.g. the requester cannot grant it). Respond
      # success with the role marked denied so it reflects the real state.
      _error ->
        {:ok,
         %{
           member: Map.put(member, :user_id, user_id),
           role: role_status(role_id, :denied)
         }}
    end
  end

  defp role_status(nil, _applied),
    do: %{role_id: nil, applied: false, status: "defaulted_to_member"}

  defp role_status(role_id, true), do: %{role_id: role_id, applied: true, status: "assigned"}

  defp role_status(role_id, false), do: %{role_id: role_id, applied: false, status: "pending"}

  defp role_status(role_id, :denied),
    do: %{role_id: role_id, applied: false, status: "denied"}

  defp audit_event({:ok, %{member: member}}, conn) do
    conn
    |> Audit.new(:User, :Added)
    |> Audit.add(
      resource_id: member[:user_id] || member[:handle] || "",
      resource_name: member[:handle] || ""
    )
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
