defmodule Guard.GrpcServers.Server.Test do
  use Guard.RepoCase, async: false

  alias Guard.FakeServers
  alias InternalApi.Guard.Guard, as: GuardService
  alias InternalApi.Guard.CreateMemberRequest

  require Logger

  setup do
    FunRegistry.clear!()
    FakeServers.setup_responses_for_development()
    Support.Guard.Store.clear!()

    :ok
  end

  describe "create_member" do
    setup do
      org_id = Ecto.UUID.generate()
      inviter_id = Ecto.UUID.generate()

      %{
        org_id: org_id,
        inviter_id: inviter_id
      }
    end

    test "when user is already a member => return status OK", ctx do
      {:ok, user} = Support.Factories.RbacUser.insert()

      list_accessible_orgs =
        InternalApi.RBAC.ListAccessibleOrgsResponse.new(org_ids: [ctx.org_id])

      FunRegistry.set!(Support.Fake.RbacService, :list_accessible_orgs, list_accessible_orgs)

      req =
        CreateMemberRequest.new(
          org_id: ctx.org_id,
          inviter_id: ctx.inviter_id,
          email: user.email,
          name: user.name
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.create_member(req)

      assert {:ok, create_member_response} = response
      assert create_member_response.msg == "User is already part of the organization"
      assert create_member_response.password == ""
    end

    test "when user is not a member => return status OK", ctx do
      {:ok, user} = Support.Factories.RbacUser.insert()

      req =
        CreateMemberRequest.new(
          org_id: ctx.org_id,
          inviter_id: ctx.inviter_id,
          email: user.email,
          name: user.name
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.create_member(req)

      assert {:ok, create_member_response} = response
      assert create_member_response.msg == "User added to the organization"
      assert create_member_response.password == ""
    end

    test "when connection to oidc failed => return error", ctx do
      oidc_env = Application.get_env(:guard, :oidc)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc_env)
      end)

      Guard.Mocks.OpenIDConnect.stub_oidc_connection()

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "http://localhost/manage/users"} ->
          {:error, "fooo"}
      end)

      email = "john@example.com"
      name = "John Doe"

      assert Guard.Store.RbacUser.fetch_by_email(email) == {:error, :not_found}

      req =
        CreateMemberRequest.new(
          org_id: ctx.org_id,
          inviter_id: ctx.inviter_id,
          email: email,
          name: name
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.create_member(req)

      assert Guard.Store.RbacUser.fetch_by_email(email) == {:error, :not_found}

      assert {:error, error} = response
      assert error.status == GRPC.Status.failed_precondition()
      assert error.message == "Failed to create user"
    end

    test "when user is not created yet => return status OK", ctx do
      oidc_env = Application.get_env(:guard, :oidc)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc_env)
      end)

      Guard.Mocks.OpenIDConnect.stub_oidc_connection()

      email = "john@example.com"
      name = "John Doe"
      oidc_user_id = Ecto.UUID.generate()

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "http://localhost/manage/users"} ->
          resp = %Tesla.Env{
            status: 200,
            body: "",
            headers: [{"location", "users/#{oidc_user_id}"}]
          }

          {:ok, resp}
      end)

      assert Guard.Store.RbacUser.fetch_by_email(email) == {:error, :not_found}

      req =
        CreateMemberRequest.new(
          org_id: ctx.org_id,
          inviter_id: ctx.inviter_id,
          email: email,
          name: name
        )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.create_member(req)

      {:ok, user} = Guard.Store.RbacUser.fetch_by_email(email)
      assert Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id) == {:ok, user}
      assert user.name == name

      assert {:ok, create_member_response} = response
      assert create_member_response.msg == "User added to the organization"
      assert create_member_response.password != ""
    end
  end

  describe "reset_password" do
    alias InternalApi.Guard.ResetPasswordRequest, as: Request

    test "when user do not exist => return error" do
      user_id = Ecto.UUID.generate()
      requester_id = Ecto.UUID.generate()

      req = Request.new(requester_id: requester_id, user_id: user_id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.reset_password(req)

      assert {:error, error} = response
      assert error.status == GRPC.Status.failed_precondition()
      assert error.message == "User not found"
    end

    test "when connection to oidc failed => return error" do
      requester_id = Ecto.UUID.generate()
      oidc_user_id = "479e18ca-71ab-4753-931a-a27d2be0c36a"

      {:ok, user} = Support.Factories.RbacUser.insert()
      Guard.Store.OIDCUser.connect_user(oidc_user_id, user.id)

      oidc_env = Application.get_env(:guard, :oidc)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc_env)
      end)

      Guard.Mocks.OpenIDConnect.stub_oidc_connection()

      Tesla.Mock.mock_global(fn
        %{method: :put, url: "http://localhost/manage/users/479e18ca-71ab-4753-931a-a27d2be0c36a"} ->
          {:error, "fooo"}
      end)

      req = Request.new(requester_id: requester_id, user_id: user.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.reset_password(req)

      assert {:error, error} = response
      assert error.status == GRPC.Status.internal()
      assert error.message == "Failed to reset password"
    end

    test "when password is reset => return password" do
      oidc_env = Application.get_env(:guard, :oidc)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc_env)
      end)

      requester_id = Ecto.UUID.generate()
      oidc_user_id = "479e18ca-71ab-4753-931a-a27d2be0c36a"

      {:ok, user} = Support.Factories.RbacUser.insert()
      Guard.Store.OIDCUser.connect_user(oidc_user_id, user.id)

      Guard.Mocks.OpenIDConnect.stub_oidc_connection()

      Tesla.Mock.mock_global(fn
        %{method: :put, url: "http://localhost/manage/users/479e18ca-71ab-4753-931a-a27d2be0c36a"} ->
          resp = %Tesla.Env{
            status: 200,
            body: "",
            headers: [{"location", "users/#{oidc_user_id}"}]
          }

          {:ok, resp}
      end)

      req = Request.new(requester_id: requester_id, user_id: user.id)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      response = channel |> GuardService.Stub.reset_password(req)

      assert {:ok, rsp} = response
      assert rsp.msg == "Password reset successfully"
      assert rsp.password != ""
    end
  end

  describe "change_email" do
    alias InternalApi.Guard.ChangeEmailRequest, as: Request

    test "when user do not exist => return error" do
      user_id = Ecto.UUID.generate()
      requester_id = Ecto.UUID.generate()

      req = Request.new(requester_id: requester_id, user_id: user_id, email: "test@semaphore.com")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.change_email(req)

      assert {:error, error} = response
      assert error.status == GRPC.Status.failed_precondition()
      assert error.message == "User not found"
    end

    test "when connection to oidc failed => return error" do
      requester_id = Ecto.UUID.generate()
      oidc_user_id = "479e18ca-71ab-4753-931a-a27d2be0c36a"

      {:ok, user} = Support.Factories.RbacUser.insert()

      {:ok, _} =
        Support.Factories.FrontUser.insert(id: user.id, email: user.email, name: user.name)

      Guard.Store.OIDCUser.connect_user(oidc_user_id, user.id)

      oidc_env = Application.get_env(:guard, :oidc)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc_env)
      end)

      Guard.Mocks.OpenIDConnect.stub_oidc_connection()

      Tesla.Mock.mock_global(fn
        %{method: :put, url: "http://localhost/manage/users/479e18ca-71ab-4753-931a-a27d2be0c36a"} ->
          {:error, "fooo"}
      end)

      req = Request.new(requester_id: requester_id, user_id: user.id, email: "test@semaphore.com")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.change_email(req)

      assert {:error, error} = response
      assert error.status == GRPC.Status.failed_precondition()
      assert error.message == "Failed to change email"
    end

    test "accepts only valid emails" do
      oidc_env = Application.get_env(:guard, :oidc)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc_env)
      end)

      requester_id = Ecto.UUID.generate()

      {:ok, user} = Support.Factories.RbacUser.insert()

      {:ok, _} =
        Support.Factories.FrontUser.insert(id: user.id, email: user.email, name: user.name)

      req = Request.new(requester_id: requester_id, user_id: user.id, email: "semaphore.com")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.change_email(req)

      assert {:error, error} = response
      assert error.status == GRPC.Status.failed_precondition()
      assert error.message == "Email is not a valid email"
    end

    test "when updating email in front db fails => rollback" do
      requester_id = Ecto.UUID.generate()
      oidc_user_id = "479e18ca-71ab-4753-931a-a27d2be0c36a"

      {:ok, user} = Support.Factories.RbacUser.insert()

      user_id = user.id
      user_mail = user.email

      {:ok, _} = Guard.Store.OIDCUser.connect_user(oidc_user_id, user_id)

      req = Request.new(requester_id: requester_id, user_id: user_id, email: "test@semaphore.com")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.change_email(req)
      assert {:error, _} = response

      user = Guard.Store.RbacUser.fetch(user_id)
      assert user.email == user_mail
    end

    test "when updating email in oidc fails => rollback" do
      requester_id = Ecto.UUID.generate()
      oidc_user_id = "479e18ca-71ab-4753-931a-a27d2be0c36a"

      {:ok, user} = Support.Factories.RbacUser.insert()

      user_id = user.id
      user_mail = user.email
      user_name = user.name

      {:ok, _} =
        Support.Factories.FrontUser.insert(id: user_id, email: user_mail, name: user_name)

      {:ok, _} = Guard.Store.OIDCUser.connect_user(oidc_user_id, user_id)

      Guard.Mocks.OpenIDConnect.stub_oidc_connection()

      Tesla.Mock.mock_global(fn
        %{
          method: :put,
          url: "http://localhost/manage/users/479e18ca-71ab-4753-931a-a27d2be0c36a",
          body: body
        } ->
          assert body =~ ~r{"email":"test@semaphore.com"}

          resp = %Tesla.Env{
            status: 422,
            body: "",
            headers: [{"location", "users/#{oidc_user_id}"}]
          }

          {:ok, resp}
      end)

      req = Request.new(requester_id: requester_id, user_id: user_id, email: "test@semaphore.com")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.change_email(req)
      assert {:error, _} = response

      {:ok, user} = Guard.FrontRepo.User.active_user_by_id(user_id)
      assert user.email == user_mail

      user = Guard.Store.RbacUser.fetch(user_id)
      assert user.email == user_mail
    end

    test "when email is changed => returns email and a message" do
      oidc_env = Application.get_env(:guard, :oidc)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc_env)
      end)

      requester_id = Ecto.UUID.generate()
      oidc_user_id = "479e18ca-71ab-4753-931a-a27d2be0c36a"

      {:ok, user} = Support.Factories.RbacUser.insert()

      {:ok, _} =
        Support.Factories.FrontUser.insert(id: user.id, email: user.email, name: user.name)

      {:ok, _} = Guard.Store.OIDCUser.connect_user(oidc_user_id, user.id)

      Guard.Mocks.OpenIDConnect.stub_oidc_connection()

      Tesla.Mock.mock_global(fn
        %{
          method: :put,
          url: "http://localhost/manage/users/479e18ca-71ab-4753-931a-a27d2be0c36a",
          body: body
        } ->
          assert body =~ ~r{"email":"test@semaphore.com"}

          resp = %Tesla.Env{
            status: 200,
            body: "",
            headers: [{"location", "users/#{oidc_user_id}"}]
          }

          {:ok, resp}
      end)

      req = Request.new(requester_id: requester_id, user_id: user.id, email: "test@semaphore.com")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      response = channel |> GuardService.Stub.change_email(req)

      assert {:ok, rsp} = response
      assert rsp.msg == "Email changed successfully"
      assert rsp.email == req.email
    end
  end

  describe "invite_collaborators" do
    setup do
      org = Support.Factories.organization()
      org_id = org.org_id
      Support.Factories.Organization.insert!(id: org_id)

      {:ok, inviter} = Support.Factories.RbacUser.insert()

      {:ok, _front_user} =
        Support.Factories.FrontUser.insert(id: inviter.id, name: "inviter_user")

      ["github", "gitlab"]
      |> Enum.each(fn repo_host ->
        Support.Members.insert_repo_host_account(
          login: "inviter_#{repo_host}",
          name: "inviter_#{repo_host}",
          github_uid: "11111",
          user_id: inviter.id,
          token: "token",
          repo_host: repo_host,
          revoked: false,
          permission_scope: "repo"
        )
      end)

      {:ok, inviting_user} = Support.Factories.RbacUser.insert()

      {:ok, _front_user} =
        Support.Factories.FrontUser.insert(id: inviting_user.id, name: "inviting_user")

      ["github", "gitlab"]
      |> Enum.each(fn repo_host ->
        Support.Members.insert_repo_host_account(
          login: "inviting_#{repo_host}",
          name: "inviting_#{repo_host}",
          github_uid: "22222",
          user_id: inviting_user.id,
          token: "token",
          repo_host: repo_host,
          revoked: false,
          permission_scope: "repo"
        )
      end)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      %{
        org_id: org_id,
        inviter_id: inviter.id,
        channel: channel
      }
    end

    alias InternalApi.Guard.InviteCollaboratorsRequest, as: Request

    test "invites user by github login", %{
      org_id: org_id,
      inviter_id: inviter_id,
      channel: channel
    } do
      invitees = [
        InternalApi.Guard.Invitee.new(
          provider:
            InternalApi.User.RepositoryProvider.new(
              type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB),
              login: "inviting_github"
            )
        )
      ]

      req =
        Request.new(
          inviter_id: inviter_id,
          org_id: org_id,
          invitees: invitees
        )

      assert {:ok, response} = channel |> GuardService.Stub.invite_collaborators(req)

      response_invitees =
        response.invitees
        |> Enum.sort_by(& &1.provider.login)

      assert [github_invitee] = response_invitees

      assert github_invitee.provider.login == "inviting_github"

      assert github_invitee.provider.type ==
               InternalApi.User.RepositoryProvider.Type.value(:GITHUB)
    end

    test "invites user by gitlab login", %{
      org_id: org_id,
      inviter_id: inviter_id,
      channel: channel
    } do
      invitees = [
        InternalApi.Guard.Invitee.new(
          provider:
            InternalApi.User.RepositoryProvider.new(
              type: InternalApi.User.RepositoryProvider.Type.value(:GITLAB),
              login: "inviting_gitlab"
            )
        )
      ]

      req =
        Request.new(
          inviter_id: inviter_id,
          org_id: org_id,
          invitees: invitees
        )

      assert {:ok, response} = channel |> GuardService.Stub.invite_collaborators(req)

      response_invitees = response.invitees
      assert [gitlab_invitee] = response_invitees

      assert gitlab_invitee.provider.login == "inviting_gitlab"

      assert gitlab_invitee.provider.type ==
               InternalApi.User.RepositoryProvider.Type.value(:GITLAB)
    end
  end
end
