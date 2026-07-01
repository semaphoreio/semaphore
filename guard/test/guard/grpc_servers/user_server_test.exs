defmodule Guard.GrpcServers.UserServerTest do
  use Guard.RepoCase, async: false
  require Logger

  alias InternalApi.User
  alias InternalApi.User.UserService.Stub

  import Mock
  import Tesla.Mock

  setup do
    {:ok, user} = Support.Factories.RbacUser.insert()
    {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)
    {:ok, another_user} = Support.Factories.RbacUser.insert()
    {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(another_user.id)
    {:ok, no_repo_user} = Support.Factories.RbacUser.insert()
    {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(another_user.id)

    {:ok, _} =
      Support.Members.insert_user(
        id: user.id,
        email: user.email,
        name: user.name
      )

    {:ok, _} =
      Support.Members.insert_user(
        id: another_user.id,
        email: another_user.email,
        name: another_user.name
      )

    {:ok, _} =
      Support.Members.insert_user(
        id: no_repo_user.id,
        email: no_repo_user.email,
        name: no_repo_user.name
      )

    {:ok, repo_host_account} =
      Support.Members.insert_repo_host_account(
        login: "radwo",
        name: "radwo",
        github_uid: "184065",
        user_id: user.id,
        token: "token",
        revoked: false,
        permission_scope: "repo"
      )

    {:ok, _} =
      Support.Members.insert_repo_host_account(
        login: "another_user",
        name: "another_user",
        user_id: another_user.id,
        github_uid: "11111",
        revoked: false,
        permission_scope: "repo"
      )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    {:ok,
     %{
       grpc_channel: channel,
       user: user,
       another_user: another_user,
       no_repo_user: no_repo_user,
       repo_host_account: repo_host_account
     }}
  end

  describe "describe" do
    test "describe should return a valid user with repository account details", %{
      grpc_channel: channel,
      user: user
    } do
      request = User.DescribeRequest.new(user_id: user.id)

      {:ok, response} =
        channel
        |> Stub.describe(request)

      email = user.email
      id = user.id

      assert %User.DescribeResponse{
               email: ^email,
               user_id: ^id,
               repository_scopes: %User.RepositoryScopes{
                 github: %User.RepositoryScopes.RepositoryScope{
                   login: "radwo"
                 }
               }
             } = response
    end

    test "describe should return a valid user with without repository account details", %{
      grpc_channel: channel,
      no_repo_user: no_repo_user
    } do
      request = User.DescribeRequest.new(user_id: no_repo_user.id)

      {:ok, response} =
        channel
        |> Stub.describe(request)

      email = no_repo_user.email
      id = no_repo_user.id

      assert %User.DescribeResponse{
               email: ^email,
               user_id: ^id,
               repository_scopes: %User.RepositoryScopes{
                 github: nil,
                 bitbucket: nil
               },
               repository_providers: []
             } = response
    end

    test "describe should return a valid user even if github token is not set", %{
      grpc_channel: channel
    } do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          github_uid: "184065",
          user_id: user.id
        )

      request = User.DescribeRequest.new(user_id: user.id)

      {:ok, response} =
        channel
        |> Stub.describe(request)

      email = user.email
      id = user.id

      assert %User.DescribeResponse{
               email: ^email,
               user_id: ^id,
               github_token: "",
               repository_scopes: %User.RepositoryScopes{
                 github: %User.RepositoryScopes.RepositoryScope{
                   login: ""
                 }
               }
             } = response
    end

    test "describe should raise not_found error for not inserted user_id", %{
      grpc_channel: channel
    } do
      random_user_id = Ecto.UUID.generate()
      request = User.DescribeRequest.new(user_id: random_user_id)

      {:error, grpc_error} =
        channel
        |> Stub.describe(request)

      not_found_grpc_error = GRPC.Status.not_found()

      assert %GRPC.RPCError{
               status: ^not_found_grpc_error,
               message: error_message
             } = grpc_error

      assert error_message == "User with id #{random_user_id} not found"
    end
  end

  describe "describe_by_email" do
    test "should return the user by the email",
         %{
           grpc_channel: channel,
           user: user,
           repo_host_account: repo_host_account
         } do
      request = User.DescribeByEmailRequest.new(email: user.email)

      {:ok, response} =
        channel
        |> Stub.describe_by_email(request)

      user_id = user.id
      email = user.email
      github_uid = repo_host_account.github_uid

      assert %User.User{
               id: ^user_id,
               email: ^email,
               repository_providers: [
                 %User.RepositoryProvider{
                   login: "radwo",
                   uid: ^github_uid
                 }
               ]
             } = response
    end

    test "should return a not_found error if user does not exist",
         %{
           grpc_channel: channel
         } do
      request = User.DescribeByEmailRequest.new(email: "foo@foo.foo")

      {:error, grpc_error} =
        channel
        |> Stub.describe_by_email(request)

      grpc_not_found_status = GRPC.Status.not_found()

      assert %GRPC.RPCError{
               status: ^grpc_not_found_status,
               message: error_message
             } = grpc_error

      assert error_message == "User not found."
    end
  end

  describe "describe_by_repository_provider" do
    test "describe_by_repository_provider should return the user related to its github uid and provider type",
         %{
           grpc_channel: channel,
           user: user,
           repo_host_account: repo_host_account
         } do
      request =
        User.DescribeByRepositoryProviderRequest.new(
          provider:
            User.RepositoryProvider.new(
              type: User.RepositoryProvider.Type.value(:GITHUB),
              uid: repo_host_account.github_uid
            )
        )

      {:ok, response} =
        channel
        |> Stub.describe_by_repository_provider(request)

      user_id = user.id
      email = user.email
      github_uid = repo_host_account.github_uid

      assert %User.User{
               id: ^user_id,
               email: ^email,
               repository_providers: [
                 %User.RepositoryProvider{
                   login: "radwo",
                   uid: ^github_uid
                 }
               ]
             } = response
    end

    test "describe_by_repository_provider should return a not_found error if user does not exist",
         %{
           grpc_channel: channel
         } do
      request =
        User.DescribeByRepositoryProviderRequest.new(
          provider:
            User.RepositoryProvider.new(
              type: User.RepositoryProvider.Type.value(:GITHUB),
              uid: "000000000"
            )
        )

      {:error, grpc_error} =
        channel
        |> Stub.describe_by_repository_provider(request)

      grpc_not_found_status = GRPC.Status.not_found()

      assert %GRPC.RPCError{
               status: ^grpc_not_found_status,
               message: error_message
             } = grpc_error

      assert error_message == "User not found."
    end
  end

  describe "search_users" do
    test "search_users should return a list with one user by an uuid query", %{
      grpc_channel: channel,
      user: user
    } do
      request = User.SearchUsersRequest.new(query: user.id, limit: 10)

      {:ok, response} = channel |> Stub.search_users(request)

      first_user = Enum.at(response.users, 0)

      assert %InternalApi.User.SearchUsersResponse{users: _} = response
      assert length(response.users) == 1
      assert first_user.id == user.id
    end

    test "search_users should return a list with users based on a name query", %{
      grpc_channel: channel,
      another_user: another_user
    } do
      request = User.SearchUsersRequest.new(query: another_user.name, limit: 10)

      {:ok, response} = channel |> Stub.search_users(request)

      first_user = Enum.at(response.users, 0)

      assert %InternalApi.User.SearchUsersResponse{users: _} = response
      assert length(response.users) > 0
      assert first_user.name == another_user.name
    end

    test "search_users should return a list with users based on an email query", %{
      grpc_channel: channel,
      another_user: another_user
    } do
      request = User.SearchUsersRequest.new(query: another_user.email, limit: 10)

      {:ok, response} = channel |> Stub.search_users(request)

      first_user = Enum.at(response.users, 0)

      assert %InternalApi.User.SearchUsersResponse{users: _} = response
      assert length(response.users) > 0
      assert first_user.email == another_user.email
    end

    test "search_users should return a list with users based on an 'no repo user' email query", %{
      grpc_channel: channel,
      no_repo_user: no_repo_user
    } do
      request = User.SearchUsersRequest.new(query: no_repo_user.email, limit: 10)

      {:ok, response} = channel |> Stub.search_users(request)

      first_user = Enum.at(response.users, 0)

      assert %InternalApi.User.SearchUsersResponse{users: _} = response
      assert length(response.users) > 0
      assert first_user.email == no_repo_user.email
      assert first_user.avatar_url == Guard.Avatar.default_provider_avatar()
    end

    test "search_users should return a list with users based on an partial email query", %{
      grpc_channel: channel,
      another_user: another_user
    } do
      email_length = String.length(another_user.email)
      end_of_email = String.slice(another_user.email, email_length - 5, email_length)
      request = User.SearchUsersRequest.new(query: end_of_email, limit: 10)

      {:ok, response} = channel |> Stub.search_users(request)

      first_user = Enum.at(response.users, 0)

      assert %InternalApi.User.SearchUsersResponse{users: _} = response
      assert length(response.users) > 0
      assert String.ends_with?(first_user.email, end_of_email)
    end

    test "search_users should return a list with no users based on an empty query", %{
      grpc_channel: channel
    } do
      request = User.SearchUsersRequest.new()

      {:ok, response} = channel |> Stub.search_users(request)

      assert %InternalApi.User.SearchUsersResponse{users: []} = response
      assert Enum.empty?(response.users)
    end

    test "search_users should return a list with no users based on a unmatching query", %{
      grpc_channel: channel
    } do
      request = User.SearchUsersRequest.new(query: "unmathing_query", limit: 30)

      {:ok, response} = channel |> Stub.search_users(request)

      assert %InternalApi.User.SearchUsersResponse{users: []} = response
      assert Enum.empty?(response.users)
    end
  end

  describe "describe_many" do
    test "describe_many should return a list of users based on an ids list", %{
      grpc_channel: channel,
      user: user,
      another_user: another_user,
      no_repo_user: no_repo_user
    } do
      user_ids = [user.id, another_user.id, no_repo_user.id]
      request = User.DescribeManyRequest.new(user_ids: user_ids)

      {:ok, response} = channel |> Stub.describe_many(request)

      # Response should have 3 users. Users with no repo should appear in the response
      assert Enum.count(response.users) == 3
      assert [%User.User{}, %User.User{}, %User.User{}] = response.users

      no_repo_user_response = Enum.find(response.users, fn user -> user.id == no_repo_user.id end)

      # No repo user should appear in the response with empty repository providers
      assert no_repo_user_response != nil
      assert no_repo_user_response.name == no_repo_user.name
      assert no_repo_user_response.repository_providers == []

      assert Enum.all?(user_ids, fn id ->
               Enum.any?(response.users, fn user -> user.id == id end)
             end)
    end

    test "describe_many should return a list an empty list if no params are given", %{
      grpc_channel: channel
    } do
      request = User.DescribeManyRequest.new()

      {:ok, response} = channel |> Stub.describe_many(request)

      assert Enum.empty?(response.users)
      assert [] = response.users
    end
  end

  describe "update" do
    test "update should update user details with valid input", %{
      grpc_channel: channel
    } do
      {:module, updated_consumer, _, _} =
        Support.Events.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:guard, :amqp_url),
          "user_exchange",
          "updated",
          "guard-service-test",
          :user_updated_test
        )

      {:module, work_email_consumer, _, _} =
        Support.Events.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:guard, :amqp_url),
          "user_exchange",
          "work_email_added",
          "guard-service-test",
          :user_work_email_added
        )

      {:ok, _} = updated_consumer.start_link()
      {:ok, _} = work_email_consumer.start_link()

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, _repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "test",
          name: "test",
          repo_host: "github",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      new_name = "Updated Name"
      new_email = "test@test.com"
      new_company = "Updated Company"

      request =
        User.UpdateRequest.new(
          user:
            User.User.new(
              id: user.id,
              name: new_name,
              email: new_email,
              company: new_company
            )
        )

      {:ok, response} =
        channel
        |> Stub.update(request)

      assert %User.UpdateResponse{
               user: %User.User{name: ^new_name, email: ^new_email, company: ^new_company}
             } = response

      receive do
        {:user_updated_test, received_message} ->
          user_updated = User.UserUpdated.decode(received_message)
          assert user_updated.user_id == user.id
      after
        5000 -> flunk("Timeout: Message not received within 5 seconds")
      end

      receive do
        {:user_work_email_added, received_message} ->
          user_work_email_added = User.WorkEmailAdded.decode(received_message)
          assert user_work_email_added.user_id == user.id
          assert user_work_email_added.new_email == new_email
      after
        5000 -> flunk("Timeout: Message not received within 5 seconds")
      end
    end

    test "update should return an error for invalid user_id", %{
      grpc_channel: channel
    } do
      random_user_id = Ecto.UUID.generate()
      request = User.UpdateRequest.new(user_id: random_user_id, name: "Updated Name")

      {:error, grpc_error} =
        channel
        |> Stub.update(request)

      invalid_argument_grpc_error = GRPC.Status.invalid_argument()

      assert %GRPC.RPCError{
               status: ^invalid_argument_grpc_error,
               message: error_message
             } = grpc_error

      assert error_message == "Invalid user."
    end
  end

  describe "delete_with_owned_orgs" do
    test "delete_with_owned_orgs should delete the user", %{
      grpc_channel: channel
    } do
      alias Guard.FrontRepo

      {:module, consumer_module, _, _} =
        Support.Events.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:guard, :amqp_url),
          "user_exchange",
          "deleted",
          "guard-service-test",
          :user_deleted_test
        )

      {:ok, _} = consumer_module.start_link()

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "test",
          name: "test",
          github_uid: "123123",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      {:ok, member} = Support.Members.insert_member(github_uid: "123123")

      request = User.DeleteWithOwnedOrgsRequest.new(user_id: user.id)

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:ok,
           InternalApi.Projecthub.ListResponse.new(
             metadata: InternalApi.Projecthub.ResponseMeta.new(status: %{code: 0}),
             projects: []
           )}
        end do
        with_mock InternalApi.RBAC.RBAC.Stub,
          list_accessible_orgs: fn _channel, _req, _opts ->
            {:ok, InternalApi.RBAC.ListAccessibleOrgsResponse.new(org_ids: [])}
          end do
          {:ok, response} = channel |> Stub.delete_with_owned_orgs(request)

          id = user.id
          assert %User.User{id: ^id} = response

          # check if the user is deleted
          assert nil == FrontRepo.get(FrontRepo.User, id)
          assert nil == FrontRepo.get(FrontRepo.RepoHostAccount, repo_host_account.id)
          assert nil == FrontRepo.get(FrontRepo.Member, member.id)

          receive do
            {:user_deleted_test, received_message} ->
              user_deleted = User.UserDeleted.decode(received_message)
              assert user_deleted.user_id == user.id
          after
            5000 -> flunk("Timeout: Message not received within 5 seconds")
          end
        end
      end
    end

    test "delete_with_owned_orgs should not delete the user if he has owned projects", %{
      grpc_channel: channel
    } do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, _repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "test",
          name: "test",
          github_uid: "123123",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      {:ok, _member} = Support.Members.insert_member(github_uid: "123123")

      request = User.DeleteWithOwnedOrgsRequest.new(user_id: user.id)

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:ok,
           InternalApi.Projecthub.ListResponse.new(
             metadata: InternalApi.Projecthub.ResponseMeta.new(status: %{code: 0}),
             projects: [
               %InternalApi.Projecthub.Project{
                 metadata: InternalApi.Projecthub.RequestMeta.new(user_id: user.id)
               }
             ]
           )}
        end do
        {:error, grpc_error} = channel |> Stub.delete_with_owned_orgs(request)

        assert %GRPC.RPCError{
                 status: GRPC.Status.invalid_argument(),
                 message: "User #{user.id} is owner of projects."
               } == grpc_error
      end
    end

    test "delete_with_owned_orgs should return the user id even for non-existent user", %{
      grpc_channel: channel
    } do
      random_user_id = Ecto.UUID.generate()
      request = User.DeleteWithOwnedOrgsRequest.new(user_id: random_user_id)

      {:ok, response} =
        channel
        |> Stub.delete_with_owned_orgs(request)

      assert response.id == random_user_id
    end

    test "delete_with_owned_orgs should reject when user is the last owner of an org", %{
      grpc_channel: channel
    } do
      alias Guard.FrontRepo

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, other} = Support.Factories.RbacUser.insert()

      org = Support.Factories.Organization.insert!(name: "Acme", username: "acme-last-owner")

      request = User.DeleteWithOwnedOrgsRequest.new(user_id: user.id)

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:ok,
           InternalApi.Projecthub.ListResponse.new(
             metadata: InternalApi.Projecthub.ResponseMeta.new(status: %{code: 0}),
             projects: []
           )}
        end do
        with_mock InternalApi.RBAC.RBAC.Stub,
          list_accessible_orgs: fn _channel, _req, _opts ->
            {:ok, InternalApi.RBAC.ListAccessibleOrgsResponse.new(org_ids: [org.id])}
          end,
          list_members: fn _channel, _req, _opts ->
            {:ok,
             InternalApi.RBAC.ListMembersResponse.new(
               members: [owner_member(user.id), plain_member(other.id)],
               total_pages: 1
             )}
          end do
          {:error, grpc_error} = channel |> Stub.delete_with_owned_orgs(request)

          assert %GRPC.RPCError{status: status, message: message} = grpc_error
          assert status == GRPC.Status.failed_precondition()
          assert message =~ "Acme"
          assert message =~ "Transfer ownership"

          # user must NOT be deleted
          refute is_nil(FrontRepo.get(FrontRepo.User, user.id))
        end
      end
    end

    test "delete_with_owned_orgs should reject when user is the sole member of an org", %{
      grpc_channel: channel
    } do
      alias Guard.FrontRepo

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      org = Support.Factories.Organization.insert!(name: "Solo", username: "acme-sole")

      request = User.DeleteWithOwnedOrgsRequest.new(user_id: user.id)

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:ok,
           InternalApi.Projecthub.ListResponse.new(
             metadata: InternalApi.Projecthub.ResponseMeta.new(status: %{code: 0}),
             projects: []
           )}
        end do
        with_mock InternalApi.RBAC.RBAC.Stub,
          list_accessible_orgs: fn _channel, _req, _opts ->
            {:ok, InternalApi.RBAC.ListAccessibleOrgsResponse.new(org_ids: [org.id])}
          end,
          list_members: fn _channel, _req, _opts ->
            {:ok,
             InternalApi.RBAC.ListMembersResponse.new(
               members: [plain_member(user.id)],
               total_pages: 1
             )}
          end do
          {:error, grpc_error} = channel |> Stub.delete_with_owned_orgs(request)

          assert %GRPC.RPCError{status: status, message: message} = grpc_error
          assert status == GRPC.Status.failed_precondition()
          assert message =~ "Solo"

          refute is_nil(FrontRepo.get(FrontRepo.User, user.id))
        end
      end
    end

    test "delete_with_owned_orgs should allow deletion when org has another owner", %{
      grpc_channel: channel
    } do
      alias Guard.FrontRepo

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, other} = Support.Factories.RbacUser.insert()

      org = Support.Factories.Organization.insert!(name: "Shared", username: "acme-coowner")

      request = User.DeleteWithOwnedOrgsRequest.new(user_id: user.id)

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:ok,
           InternalApi.Projecthub.ListResponse.new(
             metadata: InternalApi.Projecthub.ResponseMeta.new(status: %{code: 0}),
             projects: []
           )}
        end do
        with_mock InternalApi.RBAC.RBAC.Stub,
          list_accessible_orgs: fn _channel, _req, _opts ->
            {:ok, InternalApi.RBAC.ListAccessibleOrgsResponse.new(org_ids: [org.id])}
          end,
          list_members: fn _channel, _req, _opts ->
            {:ok,
             InternalApi.RBAC.ListMembersResponse.new(
               members: [owner_member(user.id), owner_member(other.id)],
               total_pages: 1
             )}
          end do
          {:ok, response} = channel |> Stub.delete_with_owned_orgs(request)

          id = user.id
          assert %User.User{id: ^id} = response
          assert is_nil(FrontRepo.get(FrontRepo.User, id))
        end
      end
    end
  end

  defp owner_member(subject_id), do: rbac_member(subject_id, "Owner")
  defp plain_member(subject_id), do: rbac_member(subject_id, "Member")

  defp rbac_member(subject_id, role_name) do
    InternalApi.RBAC.ListMembersResponse.Member.new(
      subject:
        InternalApi.RBAC.Subject.new(
          subject_id: subject_id,
          subject_type: InternalApi.RBAC.SubjectType.value(:USER)
        ),
      subject_role_bindings: [
        InternalApi.RBAC.SubjectRoleBinding.new(
          role: InternalApi.RBAC.Role.new(id: Ecto.UUID.generate(), name: role_name)
        )
      ]
    )
  end

  describe "regenerate_token" do
    test "regenerate_token should return an success response with a new token", %{
      grpc_channel: channel,
      user: user
    } do
      request = User.RegenerateTokenRequest.new(user_id: user.id)

      {:ok, response} = channel |> Stub.regenerate_token(request)
      digest = Guard.AuthenticationToken.hash_token(response.api_token)

      assert response.status.code == Google.Rpc.Code.value(:OK)
      assert is_binary(response.api_token)
      assert String.length(response.api_token) == 20
      assert {:ok, _user} = Guard.FrontRepo.User.active_user_by_token(digest)
    end

    test "regenerate_token should return a not found error for not existing user", %{
      grpc_channel: channel
    } do
      user_id = Ecto.UUID.generate()
      request = User.RegenerateTokenRequest.new(user_id: user_id)

      {:error, response} = channel |> Stub.regenerate_token(request)

      assert %GRPC.RPCError{
               status: GRPC.Status.not_found(),
               message: "User '#{user_id}' not found"
             } == response
    end
  end

  describe "list_favorites" do
    test "list_favorites should return a list of favorites based on an user and organization id",
         %{grpc_channel: channel, user: user} do
      organization_id = Ecto.UUID.generate()

      favorites =
        1..4
        |> Task.async_stream(
          fn _ ->
            {:ok, favorite} =
              Support.Factories.Favorite.insert(%{
                user_id: user.id,
                organization_id: organization_id
              })

            favorite
          end,
          max_concurrency: 4,
          timeout: 30_000
        )
        |> Enum.map(fn {:ok, favorite} -> favorite end)

      request =
        User.ListFavoritesRequest.new(
          user_id: user.id,
          organization_id: organization_id
        )

      {:ok, response} = channel |> Stub.list_favorites(request)

      assert %User.ListFavoritesResponse{favorites: _} = response
      assert length(response.favorites) == 4

      assert Enum.all?(favorites, fn favorite ->
               Enum.any?(response.favorites, fn f -> f.favorite_id == favorite.favorite_id end)
             end)
    end

    test "list_favorites should return an error based unexisting parameters", %{
      grpc_channel: channel
    } do
      request =
        User.ListFavoritesRequest.new(
          user_id: "test",
          organization_id: "test"
        )

      {:error, message} = channel |> Stub.list_favorites(request)

      status = GRPC.Status.invalid_argument()

      assert %GRPC.RPCError{
               status: ^status
             } = message
    end
  end

  describe "create_favorite" do
    test "create_favorite should create a favorite with success", %{
      grpc_channel: channel,
      user: user
    } do
      {:module, consumer_module, _, _} =
        Support.Events.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:guard, :amqp_url),
          "user_exchange",
          "favorite_created",
          "guard-service-test",
          :favorite_created_test
        )

      {:ok, _} = consumer_module.start_link()

      request =
        User.Favorite.new(
          kind: User.Favorite.Kind.value(:PROJECT),
          user_id: user.id,
          organization_id: Ecto.UUID.generate(),
          favorite_id: Ecto.UUID.generate()
        )

      {:ok, response} = channel |> Stub.create_favorite(request)

      assert response == request

      receive do
        {:favorite_created_test, received_message} ->
          favorite_created = User.FavoriteCreated.decode(received_message)
          assert favorite_created.favorite == request
      after
        5000 -> flunk("Timeout: Message not received within 5 seconds")
      end
    end

    test "create_favorite should return an error based on invalid parameters", %{
      grpc_channel: channel
    } do
      request =
        User.Favorite.new(
          kind: User.Favorite.Kind.value(:PROJECT),
          user_id: "test",
          organization_id: "test",
          favorite_id: "test"
        )

      {:error, response} = channel |> Stub.create_favorite(request)

      status = GRPC.Status.invalid_argument()

      assert %GRPC.RPCError{
               status: ^status
             } = response
    end
  end

  describe "delete_favorite" do
    test "delete_favorite should delete a favorite with success", %{
      grpc_channel: channel,
      user: user
    } do
      {:module, consumer_module, _, _} =
        Support.Events.TestConsumer.create_test_consumer(
          self(),
          Application.get_env(:guard, :amqp_url),
          "user_exchange",
          "favorite_deleted",
          "guard-service-test",
          :favorite_deleted_test
        )

      {:ok, _} = consumer_module.start_link()

      {:ok, favorite} = Support.Factories.Favorite.insert(%{user_id: user.id, kind: "PROJECT"})

      favorite_pb =
        User.Favorite.new(
          kind: User.Favorite.Kind.value(:PROJECT),
          user_id: favorite.user_id,
          organization_id: favorite.organization_id,
          favorite_id: favorite.favorite_id
        )

      request =
        User.Favorite.new(
          kind: User.Favorite.Kind.value(:PROJECT),
          user_id: favorite.user_id,
          organization_id: favorite.organization_id,
          favorite_id: favorite.favorite_id
        )

      {:ok, response} = channel |> Stub.delete_favorite(request)

      assert favorite_pb == response

      receive do
        {:favorite_deleted_test, received_message} ->
          favorite_deleted = User.FavoriteDeleted.decode(received_message)
          assert favorite_deleted.favorite == request
      after
        5000 -> flunk("Timeout: Message not received within 5 seconds")
      end
    end

    test "delete_favorite should return a not found error if no favorite is found", %{
      grpc_channel: channel
    } do
      request =
        User.Favorite.new(
          kind: User.Favorite.Kind.value(:PROJECT),
          user_id: Ecto.UUID.generate(),
          organization_id: Ecto.UUID.generate(),
          favorite_id: Ecto.UUID.generate()
        )

      {:error, response} = channel |> Stub.delete_favorite(request)

      status = GRPC.Status.not_found()

      assert %GRPC.RPCError{
               status: status,
               message: "Favorite not found."
             } == response
    end
  end

  describe "block_account" do
    test "block_account block an user and return it with success", %{grpc_channel: channel} do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      request = User.BlockAccountRequest.new(user_id: user.id)

      {:ok, response} = channel |> Stub.block_account(request)

      id = user.id
      assert %User.User{id: ^id} = response
      assert response.blocked_at != nil
    end

    test "block_account should raise not_found error for not inserted user_id", %{
      grpc_channel: channel
    } do
      random_user_id = Ecto.UUID.generate()
      request = User.BlockAccountRequest.new(user_id: random_user_id)

      {:error, grpc_error} =
        channel
        |> Stub.block_account(request)

      not_found_grpc_error = GRPC.Status.not_found()

      assert %GRPC.RPCError{
               status: ^not_found_grpc_error,
               message: error_message
             } = grpc_error

      assert error_message == "User: #{random_user_id} not found"
    end
  end

  describe "unblock_account" do
    test "unblock_account should unblock account with success", %{grpc_channel: channel} do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name,
          blocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      request = User.UnblockAccountRequest.new(user_id: user.id)

      {:ok, response} = channel |> Stub.unblock_account(request)

      id = user.id
      assert %User.User{id: ^id} = response
      assert response.blocked_at == nil
    end

    test "unblock_account should raise not_found error for not inserted user_id", %{
      grpc_channel: channel
    } do
      random_user_id = Ecto.UUID.generate()
      request = User.UnblockAccountRequest.new(user_id: random_user_id)

      {:error, grpc_error} =
        channel
        |> Stub.unblock_account(request)

      not_found_grpc_error = GRPC.Status.not_found()

      assert %GRPC.RPCError{
               status: ^not_found_grpc_error,
               message: error_message
             } = grpc_error

      assert error_message == "User: #{random_user_id} not found"
    end
  end

  describe "get_repository_token" do
    test "get_repository_token should raise invalid_argument for unsupported integration type",
         %{grpc_channel: channel} do
      request =
        User.GetRepositoryTokenRequest.new(
          integration_type: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)
        )

      {:error, response} = channel |> Stub.get_repository_token(request)

      assert %GRPC.RPCError{
               status: GRPC.Status.invalid_argument(),
               message: "Integration Type: 'GITHUB_APP' is not supported."
             } == response
    end

    test "get_repository_token should return a valid github repository token",
         %{grpc_channel: channel, user: user} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "mock_token", "expires_in" => 3600}}}

        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      request =
        User.GetRepositoryTokenRequest.new(
          user_id: user.id,
          integration_type:
            InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)
        )

      {:ok, response} = channel |> Stub.get_repository_token(request)

      assert response == %User.GetRepositoryTokenResponse{
               expires_at: nil,
               token: "token"
             }
    end

    test "get_repository_token should return a valid bitbucket repository token",
         %{grpc_channel: channel} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "mock_token", "expires_in" => 3600}}}
      end)

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, _repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          name: "radwo",
          repo_host: "bitbucket",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      request =
        User.GetRepositoryTokenRequest.new(
          user_id: user.id,
          integration_type: InternalApi.RepositoryIntegrator.IntegrationType.value(:BITBUCKET)
        )

      {:ok, response} = channel |> Stub.get_repository_token(request)

      assert %User.GetRepositoryTokenResponse{
               expires_at: expires_at,
               token: "mock_token"
             } = response

      assert expires_at > DateTime.utc_now() |> DateTime.to_unix(:second)
    end

    test "get_repository_token should return a valid gitlab repository token",
         %{grpc_channel: channel} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: %{
               "access_token" => "mock_token",
               "expires_in" => 3600,
               refresh_token: "refresh_token"
             }
           }}
      end)

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, _repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          name: "radwo",
          repo_host: "gitlab",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      request =
        User.GetRepositoryTokenRequest.new(
          user_id: user.id,
          integration_type: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITLAB)
        )

      {:ok, response} = channel |> Stub.get_repository_token(request)

      assert %User.GetRepositoryTokenResponse{
               expires_at: expires_at,
               token: "mock_token"
             } = response

      assert expires_at > DateTime.utc_now() |> DateTime.to_unix(:second)
    end
  end

  describe "refresh_repository_provider" do
    test "refresh_repository_provider should refresh repository provider details for a valid user with github",
         %{
           grpc_channel: channel,
           user: user
         } do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"valid" => "valid"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => "radwo", "name" => "radwo"})
      end)

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:GITHUB)
        )

      {:ok, response} =
        channel
        |> Stub.refresh_repository_provider(request)

      assert %User.RefreshRepositoryProviderResponse{
               user_id: user.id,
               repository_provider: %User.RepositoryProvider{
                 type: User.RepositoryProvider.Type.value(:GITHUB),
                 scope: User.RepositoryProvider.Scope.value(:PRIVATE),
                 login: "radwo",
                 uid: "184065"
               }
             } == response
    end

    test "refresh_repository_provider syncs the github login when it changed upstream",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      new_login = "#{rha.login}-renamed"

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"valid" => "valid"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => new_login, "name" => rha.name})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        request =
          User.RefreshRepositoryProviderRequest.new(
            user_id: user.id,
            type: User.RepositoryProvider.Type.value(:GITHUB)
          )

        {:ok, response} = channel |> Stub.refresh_repository_provider(request)

        assert response.repository_provider.login == new_login

        {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
        assert reloaded.login == new_login
        assert reloaded.name == rha.name
        assert reloaded.revoked == false

        assert called(Guard.Events.UserUpdated.publish(user.id, "user_exchange", "updated"))
      end
    end

    test "refresh_repository_provider syncs the github display name when it changed upstream",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      new_name = "#{rha.name} (renamed)"

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"valid" => "valid"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => rha.login, "name" => new_name})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        request =
          User.RefreshRepositoryProviderRequest.new(
            user_id: user.id,
            type: User.RepositoryProvider.Type.value(:GITHUB)
          )

        {:ok, _response} = channel |> Stub.refresh_repository_provider(request)

        {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
        assert reloaded.login == rha.login
        assert reloaded.name == new_name

        assert called(Guard.Events.UserUpdated.publish(user.id, "user_exchange", "updated"))
      end
    end

    test "refresh_repository_provider syncs login and name together when both changed",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      new_login = "#{rha.login}-v2"
      new_name = "#{rha.name} v2"

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"valid" => "valid"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => new_login, "name" => new_name})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        request =
          User.RefreshRepositoryProviderRequest.new(
            user_id: user.id,
            type: User.RepositoryProvider.Type.value(:GITHUB)
          )

        {:ok, _response} = channel |> Stub.refresh_repository_provider(request)

        {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
        assert reloaded.login == new_login
        assert reloaded.name == new_name

        assert called(Guard.Events.UserUpdated.publish(user.id, "user_exchange", "updated"))
      end
    end

    test "refresh_repository_provider is a no-op when github reports the same profile",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"valid" => "valid"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => rha.login, "name" => rha.name})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        original_updated_at = rha.updated_at

        request =
          User.RefreshRepositoryProviderRequest.new(
            user_id: user.id,
            type: User.RepositoryProvider.Type.value(:GITHUB)
          )

        {:ok, response} = channel |> Stub.refresh_repository_provider(request)

        assert response.repository_provider.login == rha.login

        {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
        assert reloaded.login == rha.login
        assert reloaded.name == rha.name
        # update_revoke_status was a no-op (status unchanged) so updated_at stays put.
        assert reloaded.updated_at == original_updated_at

        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "refresh_repository_provider is a no-op when github user fetch returns 500",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"valid" => "valid"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          {:ok, %Tesla.Env{status: 500, body: %{"message" => "boom"}}}
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        request =
          User.RefreshRepositoryProviderRequest.new(
            user_id: user.id,
            type: User.RepositoryProvider.Type.value(:GITHUB)
          )

        {:ok, response} = channel |> Stub.refresh_repository_provider(request)

        assert response.repository_provider.login == rha.login

        {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
        assert reloaded.login == rha.login
        assert reloaded.name == rha.name
        assert reloaded.revoked == false

        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "refresh_repository_provider does not clobber stored name when github returns null name",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      new_login = "#{rha.login}-renamed"

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"valid" => "valid"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => new_login, "name" => nil})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        request =
          User.RefreshRepositoryProviderRequest.new(
            user_id: user.id,
            type: User.RepositoryProvider.Type.value(:GITHUB)
          )

        {:ok, response} = channel |> Stub.refresh_repository_provider(request)

        assert response.repository_provider.login == new_login

        {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
        assert reloaded.login == new_login
        assert reloaded.name == rha.name

        assert called(Guard.Events.UserUpdated.publish(user.id, "user_exchange", "updated"))
      end
    end

    test "refresh_repository_provider does not crash and skips event when update_profile fails",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      new_login = "#{rha.login}-renamed"

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"valid" => "valid"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => new_login, "name" => rha.name})
      end)

      forced_error = {:error, %Ecto.Changeset{errors: [login: {"is invalid", []}], valid?: false}}

      with_mocks([
        {Guard.FrontRepo.RepoHostAccount, [:passthrough],
         update_profile: fn _, _ -> forced_error end},
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end}
      ]) do
        request =
          User.RefreshRepositoryProviderRequest.new(
            user_id: user.id,
            type: User.RepositoryProvider.Type.value(:GITHUB)
          )

        {:ok, response} = channel |> Stub.refresh_repository_provider(request)

        assert response.repository_provider.login == rha.login

        {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
        assert reloaded.login == rha.login
        assert reloaded.name == rha.name

        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "refresh_repository_provider revokes account when refresh_token is missing and token is invalid",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      # Fixture rha has no refresh_token. Flow proven by this test:
      #   get_token → user_token → validate_token → 401
      #   → handle_fetch_token (refresh_token in [nil, ""]) → {:error, :revoked}
      #   → get_token raises grpc_error!(:not_found, ...)
      # handle_validate_token and GithubProfileSync.sync never run.
      # No mock for /user/<uid> — if sync mistakenly tried to fetch, Tesla.Mock
      # would raise and fail the test.
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}
      end)

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:GITHUB)
        )

      {:error, _} = channel |> Stub.refresh_repository_provider(request)

      updated_account = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert updated_account.revoked == true
      assert updated_account.login == rha.login
    end

    test "refresh_repository_provider revokes account and skips profile fetch when refreshed token is rejected by validate",
         %{grpc_channel: channel} do
      # Distinct from the test above: here user_token's *refresh* path succeeds
      # (refresh_token is present, /login/oauth/access_token returns 200 with a
      # new token). Then handle_validate_token validates the NEW token,
      # api.github.com still returns 401 → {:ok, false} → update_revoke_status
      # writes revoked: true. GithubProfileSync.sync sees revoked: true and
      # passes through — /user/<uid> must NEVER be called (no mock).
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, _rha} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          name: "radwo",
          github_uid: "184065",
          repo_host: "github",
          refresh_token: "old_refresh",
          user_id: user.id,
          token: "old_token",
          revoked: false,
          permission_scope: "repo"
        )

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: %{"access_token" => "new_token", "expires_in" => 3600}
           }}
      end)

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:GITHUB)
        )

      {:ok, _response} = channel |> Stub.refresh_repository_provider(request)

      {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
      # Proves user_token's refresh path was actually exercised (the new token
      # is persisted from /login/oauth/access_token's response).
      assert reloaded.token == "new_token"
      # Proves handle_validate_token saw {:ok, false} on the new token and
      # called update_revoke_status(_, true).
      assert reloaded.revoked == true
    end

    test "refresh_repository_provider preserves revoke status on transient github validate_token 5xx",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      # Two calls to validate_token happen per refresh:
      #   1) inside user_token (must succeed to yield a token)
      #   2) inside handle_validate_token (we force 500 here)
      # Use a per-test counter to differentiate.
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          n = Agent.get_and_update(counter, &{&1 + 1, &1 + 1})

          if n == 1 do
            json(%{"valid" => "valid"})
          else
            {:ok, %Tesla.Env{status: 500, body: %{"message" => "boom"}}}
          end

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => rha.login, "name" => rha.name})
      end)

      original_updated_at = rha.updated_at

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:GITHUB)
        )

      {:ok, _response} = channel |> Stub.refresh_repository_provider(request)

      {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
      # Transient validate failure must NOT flip revoke status.
      assert reloaded.revoked == false
      # update_revoke_status was not invoked, so updated_at stays put.
      assert reloaded.updated_at == original_updated_at
    end

    test "refresh_repository_provider preserves revoke status when first validate_token returns 5xx and no refresh_token",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      # Guards against revoking a healthy account when the FIRST validate_token
      # call (inside user_token/1) hits a transient failure. Fixture rha has no
      # refresh_token; without the :transient short-circuit, user_token would
      # fall through to handle_fetch_token → {:error, :revoked} → account
      # revoked.
      original_updated_at = rha.updated_at

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 500, body: %{"message" => "boom"}}}

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => rha.login, "name" => rha.name})

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          raise "must not attempt refresh when validate is transient"
      end)

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:GITHUB)
        )

      {:ok, _response} = channel |> Stub.refresh_repository_provider(request)

      {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
      assert reloaded.revoked == false
      assert reloaded.updated_at == original_updated_at
    end

    test "refresh_repository_provider preserves revoke status when first validate_token returns 403 and no refresh_token",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      # 403 from GET https://api.github.com/ is overwhelmingly secondary
      # rate-limit, not "token revoked". It must be treated as transient and
      # leave the account untouched.
      original_updated_at = rha.updated_at

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 403, body: %{"message" => "rate limited"}}}

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => rha.login, "name" => rha.name})

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          raise "must not attempt refresh on 403"
      end)

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:GITHUB)
        )

      {:ok, _response} = channel |> Stub.refresh_repository_provider(request)

      {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
      assert reloaded.revoked == false
      assert reloaded.updated_at == original_updated_at
    end

    test "refresh_repository_provider succeeds on a legacy github account with name == nil",
         %{grpc_channel: channel, user: user, repo_host_account: rha} do
      # Before narrowing update_account's validate_required, a row with
      # name == nil would error out in update_revoke_status with a
      # :required changeset error → grpc_error!(:internal). The new sync
      # could backfill name, but never got the chance because the revoke
      # write failed first.
      {:ok, legacy_rha} =
        rha
        |> Ecto.Changeset.change(%{name: nil})
        |> Guard.FrontRepo.update(force: true)

      assert legacy_rha.name == nil

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          json(%{"login" => rha.login})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => rha.login, "name" => "Backfilled Name"})
      end)

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:GITHUB)
        )

      {:ok, _response} = channel |> Stub.refresh_repository_provider(request)

      {:ok, reloaded} = Guard.FrontRepo.RepoHostAccount.get_for_github_user(user.id)
      assert reloaded.revoked == false
      # GithubProfileSync should have backfilled the name now that the
      # revoke write no longer blocks the flow on a nil legacy field.
      assert reloaded.name == "Backfilled Name"
    end

    test "refresh_repository_provider should refresh repository provider details for a valid user with bitbucket",
         %{
           grpc_channel: channel
         } do
      Tesla.Mock.mock_global(fn env ->
        case env do
          %{
            method: :get,
            url: "https://api.bitbucket.org/2.0/user/workspaces"
          } ->
            {:ok, %Tesla.Env{status: 200, body: %{}}}

          %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: %{"access_token" => "mock_token", "expires_in" => 3600}
             }}
        end
      end)

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          name: "radwo",
          repo_host: "bitbucket",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:BITBUCKET)
        )

      {:ok, response} =
        channel
        |> Stub.refresh_repository_provider(request)

      assert %User.RefreshRepositoryProviderResponse{
               user_id: user.id,
               repository_provider: %User.RepositoryProvider{
                 type: User.RepositoryProvider.Type.value(:BITBUCKET),
                 scope: User.RepositoryProvider.Scope.value(:PRIVATE),
                 login: repo_host_account.login,
                 uid: repo_host_account.github_uid
               }
             } == response
    end

    test "refresh_repository_provider marks bitbucket account revoked for 401 responses",
         %{grpc_channel: channel} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.bitbucket.org/2.0/user/workspaces"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}
      end)

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          name: "radwo",
          repo_host: "bitbucket",
          refresh_token: "example_refresh_token",
          token_expires_at: Support.Members.valid_expires_at(),
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:BITBUCKET)
        )

      {:ok, response} =
        channel
        |> Stub.refresh_repository_provider(request)

      assert response.repository_provider.scope == User.RepositoryProvider.Scope.value(:NONE)

      updated_account =
        Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, repo_host_account.id)

      assert updated_account.revoked == true
    end

    test "refresh_repository_provider keeps revoke status unchanged for transient bitbucket failures",
         %{grpc_channel: channel} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.bitbucket.org/2.0/user/workspaces"} ->
          {:ok, %Tesla.Env{status: 503, body: %{}}}
      end)

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          name: "radwo",
          repo_host: "bitbucket",
          refresh_token: "example_refresh_token",
          token_expires_at: Support.Members.valid_expires_at(),
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:BITBUCKET)
        )

      {:ok, response} =
        channel
        |> Stub.refresh_repository_provider(request)

      assert response.repository_provider.scope == User.RepositoryProvider.Scope.value(:PRIVATE)

      updated_account =
        Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, repo_host_account.id)

      assert updated_account.revoked == false
    end

    test "refresh_repository_provider should refresh repository provider details for a valid user with gitlab",
         %{
           grpc_channel: channel
         } do
      Tesla.Mock.mock_global(fn env ->
        case env do
          %{
            method: :get,
            url: "https://gitlab.com/oauth/token/info"
          } ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: %{
                 "expires_in" => 3600
               }
             }}

          %{method: :post, url: "https://gitlab.com/oauth/token"} ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: %{
                 "access_token" => "mock_token",
                 "expires_in" => 3600,
                 "refresh_token" => "test"
               }
             }}
        end
      end)

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, repo_host_account} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          name: "radwo",
          repo_host: "gitlab",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      request =
        User.RefreshRepositoryProviderRequest.new(
          user_id: user.id,
          type: User.RepositoryProvider.Type.value(:GITLAB)
        )

      {:ok, response} =
        channel
        |> Stub.refresh_repository_provider(request)

      assert %User.RefreshRepositoryProviderResponse{
               user_id: user.id,
               repository_provider: %User.RepositoryProvider{
                 type: User.RepositoryProvider.Type.value(:GITLAB),
                 scope: User.RepositoryProvider.Scope.value(:PRIVATE),
                 login: repo_host_account.login,
                 uid: repo_host_account.github_uid
               }
             } == response
    end

    test "refresh_repository_provider should raise not_found error for non-existent user", %{
      grpc_channel: channel
    } do
      random_user_id = Ecto.UUID.generate()
      request = User.RefreshRepositoryProviderRequest.new(user_id: random_user_id)

      {:error, grpc_error} =
        channel
        |> Stub.refresh_repository_provider(request)

      not_found_grpc_error = GRPC.Status.not_found()

      assert %GRPC.RPCError{
               status: ^not_found_grpc_error,
               message: error_message
             } = grpc_error

      assert error_message == "User #{random_user_id} not found."
    end
  end

  describe "create" do
    test "should create a new user with valid input", %{grpc_channel: ch} do
      with_mock Guard.Events.UserCreated, publish: fn _user_id, _invited -> :ok end do
        email = "new.user@example.com"
        name = "New User"
        pswd = "securepassword123"

        request = User.CreateRequest.new(email: email, name: name, password: pswd)
        {:ok, response} = ch |> Stub.create(request)

        assert %User.User{email: ^email, name: ^name} = response
        assert {:ok, user} = Guard.Store.User.Front.find_by_email(email)
        assert user.name == name

        assert_called_exactly(Guard.Events.UserCreated.publish(:_, false), 1)
      end
    end

    test "should return error with invalid email format", %{grpc_channel: ch} do
      request =
        User.CreateRequest.new(
          email: "invalid-email",
          name: "New User",
          password: "securepassword123"
        )

      grpc_error = GRPC.Status.invalid_argument()
      assert {:error, %GRPC.RPCError{status: ^grpc_error}} = ch |> Stub.create(request)
    end

    test "should return error when email already exists", %{grpc_channel: ch, user: existing_user} do
      request =
        User.CreateRequest.new(
          email: existing_user.email,
          name: "New User",
          password: "securepassword123"
        )

      grpc_error = GRPC.Status.invalid_argument()
      assert {:error, %GRPC.RPCError{status: ^grpc_error}} = ch |> Stub.create(request)
    end
  end

  describe "describe service accounts" do
    test "should describe service account successfully", %{grpc_channel: channel} do
      # Create a service account using the factory
      {:ok, %{service_account: _service_account, user: user}} =
        Support.Factories.ServiceAccountFactory.insert()

      request = User.DescribeRequest.new(user_id: user.id)

      {:ok, response} = channel |> Stub.describe(request)

      assert %User.DescribeResponse{
               email: user_email,
               user_id: user_id,
               name: user_name,
               repository_providers: [],
               repository_scopes: %User.RepositoryScopes{
                 github: nil,
                 bitbucket: nil
               }
             } = response

      assert user_id == user.id
      assert user_email == user.email
      assert user_name == user.name
      assert String.contains?(user_email, "@service-accounts.")
      assert String.contains?(user_email, ".#{Application.fetch_env!(:guard, :base_domain)}")
    end

    test "should describe service account with correct user metadata", %{grpc_channel: channel} do
      # Create service account with specific details
      {:ok, %{service_account: _service_account, user: user}} =
        Support.Factories.ServiceAccountFactory.insert(
          name: "Test Service Account",
          description: "Test Description"
        )

      request = User.DescribeRequest.new(user_id: user.id)

      {:ok, response} = channel |> Stub.describe(request)

      assert %User.DescribeResponse{
               user: %User.User{
                 id: user_id,
                 name: user_name,
                 email: user_email,
                 repository_providers: [],
                 creation_source: creation_source
               }
             } = response

      assert user_id == user.id
      assert user_name == "Test Service Account"
      assert user_email == user.email
      assert user.creation_source == :service_account
      # Verify that SERVICE_ACCOUNT enum value (2) is returned
      assert creation_source == InternalApi.User.User.CreationSource.value(:SERVICE_ACCOUNT)
      assert creation_source == 2
    end

    test "should not return repository providers for service accounts", %{grpc_channel: channel} do
      # Service accounts should not have repository providers
      {:ok, %{service_account: _service_account, user: user}} =
        Support.Factories.ServiceAccountFactory.insert()

      request = User.DescribeRequest.new(user_id: user.id)

      {:ok, response} = channel |> Stub.describe(request)

      assert %User.DescribeResponse{
               repository_providers: [],
               repository_scopes: %User.RepositoryScopes{
                 github: nil,
                 bitbucket: nil
               },
               github_token: "",
               github_uid: "",
               github_login: ""
             } = response
    end

    test "should handle service account not found", %{grpc_channel: channel} do
      non_existent_id = Ecto.UUID.generate()
      request = User.DescribeRequest.new(user_id: non_existent_id)

      {:error, grpc_error} = channel |> Stub.describe(request)

      not_found_grpc_error = GRPC.Status.not_found()

      assert %GRPC.RPCError{
               status: ^not_found_grpc_error,
               message: error_message
             } = grpc_error

      assert error_message == "User with id #{non_existent_id} not found"
    end

    test "should describe service account by email", %{grpc_channel: channel} do
      {:ok, %{service_account: _service_account, user: user}} =
        Support.Factories.ServiceAccountFactory.insert()

      request = User.DescribeByEmailRequest.new(email: user.email)

      {:ok, response} = channel |> Stub.describe_by_email(request)

      assert %User.User{
               id: user_id,
               email: user_email,
               name: user_name,
               repository_providers: []
             } = response

      assert user_id == user.id
      assert user_email == user.email
      assert user_name == user.name
    end

    test "should include service accounts in search results", %{grpc_channel: channel} do
      {:ok, %{service_account: _service_account, user: user}} =
        Support.Factories.ServiceAccountFactory.insert(name: "SearchableServiceAccount")

      request =
        User.SearchUsersRequest.new(
          query: "SearchableServiceAccount",
          limit: 10
        )

      {:ok, response} = channel |> Stub.search_users(request)

      assert %User.SearchUsersResponse{users: users} = response
      assert length(users) >= 1

      service_account_user = Enum.find(users, fn u -> u.id == user.id end)
      assert service_account_user != nil
      assert service_account_user.name == "SearchableServiceAccount"
      assert service_account_user.repository_providers == []
    end

    test "should include service accounts in describe_many results", %{grpc_channel: channel} do
      {:ok, %{service_account: _sa1, user: user1}} =
        Support.Factories.ServiceAccountFactory.insert(name: "SA1")

      {:ok, %{service_account: _sa2, user: user2}} =
        Support.Factories.ServiceAccountFactory.insert(name: "SA2")

      request = User.DescribeManyRequest.new(user_ids: [user1.id, user2.id])

      {:ok, response} = channel |> Stub.describe_many(request)

      assert %User.DescribeManyResponse{users: users} = response
      assert length(users) == 2

      user_ids = Enum.map(users, & &1.id) |> Enum.sort()
      expected_ids = [user1.id, user2.id] |> Enum.sort()
      assert user_ids == expected_ids

      # All should be service accounts with no repository providers
      Enum.each(users, fn user ->
        assert user.repository_providers == []
        # Verify creation_source is SERVICE_ACCOUNT (2)
        assert user.creation_source ==
                 InternalApi.User.User.CreationSource.value(:SERVICE_ACCOUNT)

        assert user.creation_source == 2
      end)
    end

    test "should return creation_source as SERVICE_ACCOUNT for service accounts", %{
      grpc_channel: channel
    } do
      {:ok, %{service_account: _service_account, user: user}} =
        Support.Factories.ServiceAccountFactory.insert()

      request = User.DescribeRequest.new(user_id: user.id)

      {:ok, response} = channel |> Stub.describe(request)

      assert %User.DescribeResponse{
               user: %User.User{
                 creation_source: creation_source
               }
             } = response

      # Verify creation_source is exactly SERVICE_ACCOUNT (enum value 2)
      assert creation_source == InternalApi.User.User.CreationSource.value(:SERVICE_ACCOUNT)
      assert creation_source == 2
    end
  end
end
