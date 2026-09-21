defmodule Router.Members.Create.Test do
  use ExUnit.Case

  alias InternalApi.Guard.{InviteCollaboratorsResponse, Invitee}
  alias InternalApi.User.RepositoryProvider

  @github RepositoryProvider.Type.value(:GITHUB)

  setup do
    on_exit(fn -> Support.Stubs.reset() end)

    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()

    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: ["organization.people.manage"]
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()

    {:ok,
     extra_args: %{
       "organization_id" => org.id,
       "requester_id" => user.id
     }}
  end

  describe "POST /members - invite orchestration" do
    test "invites a resolvable user and applies a grantable role", ctx do
      stub_invite("octocat")
      stub_resolved_user("11111111-1111-1111-1111-111111111111")
      stub_assign_role_ok()

      body = %{provider: "github", handle: "octocat", role_id: "role-123"}
      {:ok, resp} = create_request(body, ctx)
      decoded = Poison.decode!(resp.body)

      assert resp.status_code == 200
      assert decoded["role"]["status"] == "assigned"
      assert decoded["role"]["applied"] == true
      assert decoded["member"]["user_id"] == "11111111-1111-1111-1111-111111111111"
    end

    test "adds an invitee with no Semaphore account as a pending member", ctx do
      stub_invite("newbie")
      stub_user_error(GRPC.Status.not_found())

      body = %{provider: "github", handle: "newbie", role_id: "role-123"}
      {:ok, resp} = create_request(body, ctx)
      decoded = Poison.decode!(resp.body)

      assert resp.status_code == 200
      assert decoded["role"]["status"] == "pending"
      assert decoded["role"]["applied"] == false
      assert decoded["member"]["user_id"] == nil
    end

    test "marks the role denied when the requester cannot grant it", ctx do
      stub_invite("octocat")
      stub_resolved_user("22222222-2222-2222-2222-222222222222")

      GrpcMock.stub(RBACMock, :assign_role, fn _, _ ->
        raise GRPC.RPCError,
          status: GRPC.Status.permission_denied(),
          message: "cannot grant this role"
      end)

      body = %{provider: "github", handle: "octocat", role_id: "role-123"}
      {:ok, resp} = create_request(body, ctx)
      decoded = Poison.decode!(resp.body)

      assert resp.status_code == 200
      assert decoded["role"]["status"] == "denied"
      assert decoded["role"]["applied"] == false
      assert decoded["member"]["user_id"] == "22222222-2222-2222-2222-222222222222"
    end

    test "rejects an unknown provider with a 400", ctx do
      body = %{provider: "svn", handle: "octocat"}
      {:ok, resp} = create_request(body, ctx)

      assert resp.status_code == 400
      assert resp.body =~ "provider must be one of"
    end

    test "maps a Guard failure to an error response, not a 500", ctx do
      GrpcMock.stub(GuardMock, :invite_collaborators, fn _, _ ->
        raise GRPC.RPCError,
          status: GRPC.Status.invalid_argument(),
          message: "invalid invitee"
      end)

      body = %{provider: "github", handle: "octocat"}
      {:ok, resp} = create_request(body, ctx)

      assert resp.status_code == 400
      refute resp.status_code == 500
    end

    test "degrades to pending on a user-service failure, not a 500", ctx do
      stub_invite("octocat")
      stub_user_error(GRPC.Status.internal())

      body = %{provider: "github", handle: "octocat", role_id: "role-123"}
      {:ok, resp} = create_request(body, ctx)
      decoded = Poison.decode!(resp.body)

      assert resp.status_code == 200
      refute resp.status_code == 500
      assert decoded["role"]["status"] == "pending"
    end
  end

  defp stub_invite(handle) do
    GrpcMock.stub(GuardMock, :invite_collaborators, fn _, _ ->
      InviteCollaboratorsResponse.new(
        invitees: [
          Invitee.new(
            email: "",
            name: "",
            provider: RepositoryProvider.new(type: @github, login: handle, uid: "")
          )
        ]
      )
    end)
  end

  defp stub_resolved_user(user_id) do
    GrpcMock.stub(UserMock, :describe_by_repository_provider, fn _, _ ->
      InternalApi.User.User.new(id: user_id)
    end)
  end

  defp stub_user_error(status) do
    GrpcMock.stub(UserMock, :describe_by_repository_provider, fn _, _ ->
      raise GRPC.RPCError, status: status, message: "user lookup failed"
    end)
  end

  defp stub_assign_role_ok do
    GrpcMock.stub(RBACMock, :assign_role, fn _, _ ->
      InternalApi.RBAC.AssignRoleResponse.new()
    end)
  end

  defp url, do: "localhost:4004"

  defp headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  defp create_request(body, ctx) do
    HTTPoison.post(
      url() <> "/members",
      Poison.encode!(body),
      headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"])
    )
  end
end
