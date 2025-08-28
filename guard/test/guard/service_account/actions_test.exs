defmodule Guard.ServiceAccount.ActionsTest do
  use Guard.RepoCase, async: false

  import Mock

  alias Guard.ServiceAccount.Actions
  alias Guard.Store.ServiceAccount
  alias Support.Factories.ServiceAccountFactory

  # Common mock helpers
  defp setup_common_mocks do
    [
      {Guard.Store.RbacUser, [:passthrough],
       [
         create: fn _, _, _, _ -> :ok end,
         fetch: fn _ -> %{id: "rbac-user-id", user_id: "user-id"} end
       ]},
      {Guard.Api.Rbac, [:passthrough], [assign_role: fn _, _, _ -> :ok end]},
      {Guard.Events.UserCreated, [:passthrough], [publish: fn _, _ -> :ok end]}
    ]
  end

  defp successful_service_account_mock(email \\ "test@example.com") do
    {ServiceAccount, [:passthrough],
     [
       create: fn _ ->
         {:ok,
          %{
            service_account: %{
              id: "user-id",
              user_id: "user-id",
              name: "Test SA",
              description: "Test Description",
              org_id: "org-id",
              creator_id: "creator-id",
              deactivated: false,
              email: email
            },
            api_token: "test-token"
          }}
       end
     ]}
  end

  defp rbac_failure_mocks do
    [
      {Guard.Store.RbacUser, [:passthrough], [create: fn _, _, _, _ -> :error end]},
      {Guard.Api.Rbac, [:passthrough], [assign_role: fn _, _, _ -> :ok end]},
      {Guard.Events.UserCreated, [:passthrough], [publish: fn _, _ -> :ok end]}
    ]
  end

  defp rbac_user_not_found_mocks do
    [
      {Guard.Store.RbacUser, [:passthrough],
       [
         create: fn _, _, _, _ -> :ok end,
         fetch: fn _ -> nil end
       ]},
      {Guard.Api.Rbac, [:passthrough], [assign_role: fn _, _, _ -> :ok end]}
    ]
  end

  describe "create/1" do
    test "creates service account successfully and publishes event" do
      with_mocks([successful_service_account_mock() | setup_common_mocks()]) do
        params = ServiceAccountFactory.build_params()

        {:ok, %{service_account: service_account, api_token: api_token}} = Actions.create(params)

        assert service_account.id == "user-id"
        assert service_account.name == "Test SA"
        assert api_token == "test-token"

        # Verify event was published
        assert_called(Guard.Events.UserCreated.publish("user-id", false))
      end
    end

    test "creates RBAC user during service account creation" do
      with_mocks([
        {ServiceAccount, [:passthrough],
         [
           create: fn _ ->
             {:ok,
              %{
                service_account: %{
                  id: "user-id",
                  user_id: "user-id",
                  name: "Test SA",
                  description: "Test Description",
                  org_id: "org-id",
                  creator_id: "creator-id",
                  deactivated: false,
                  email:
                    "test@service-accounts.test-org.#{Application.fetch_env!(:guard, :base_domain)}"
                },
                api_token: "test-token"
              }}
           end
         ]},
        {Guard.Store.RbacUser, [:passthrough],
         [
           create: fn user_id, email, name, "service_account" ->
             assert user_id == "user-id"

             assert email ==
                      "test@service-accounts.test-org.#{Application.fetch_env!(:guard, :base_domain)}"

             assert name == "Test SA"
             :ok
           end,
           fetch: fn _ -> %{id: "rbac-user-id", user_id: "user-id"} end
         ]},
        {Guard.Api.Rbac, [:passthrough], [assign_role: fn _, _, _ -> :ok end]},
        {Guard.Events.UserCreated, [:passthrough], [publish: fn _, _ -> :ok end]}
      ]) do
        params = ServiceAccountFactory.build_params()

        {:ok, %{service_account: _service_account, api_token: _api_token}} =
          Actions.create(params)

        # Verify RBAC user creation was called with correct params
        assert_called(
          Guard.Store.RbacUser.create(
            "user-id",
            "test@service-accounts.test-org.#{Application.fetch_env!(:guard, :base_domain)}",
            "Test SA",
            "service_account"
          )
        )
      end
    end

    test "handles service account creation failure" do
      with_mocks([
        {ServiceAccount, [:passthrough], [create: fn _ -> {:error, :creation_failed} end]},
        {Guard.Api.Rbac, [:passthrough], [assign_role: fn _, _, _ -> :ok end]}
      ]) do
        params = ServiceAccountFactory.build_params()

        {:error, :creation_failed} = Actions.create(params)
      end
    end

    test "handles RBAC user creation failure" do
      with_mocks([successful_service_account_mock() | rbac_failure_mocks()]) do
        params = ServiceAccountFactory.build_params()

        {:error, :rbac_user_creation_failed} = Actions.create(params)

        # Verify event was NOT published on failure
        refute called(Guard.Events.UserCreated.publish(:_, :_))
      end
    end

    test "handles RBAC user fetch failure after creation" do
      with_mocks([successful_service_account_mock() | rbac_user_not_found_mocks()]) do
        params = ServiceAccountFactory.build_params()

        {:error, :rbac_user_not_found} = Actions.create(params)
      end
    end

    test "handles service account store creation failure" do
      with_mocks([
        {ServiceAccount, [:passthrough], [create: fn _ -> {:error, :creation_failed} end]},
        {Guard.Api.Rbac, [:passthrough], [assign_role: fn _, _, _ -> :ok end]}
      ]) do
        params = ServiceAccountFactory.build_params()

        {:error, :creation_failed} = Actions.create(params)

        # Verify the store was called
        assert_called(ServiceAccount.create(params))
      end
    end
  end

  describe "update/2" do
    test "updates service account successfully" do
      service_account_id = "sa-id"
      update_params = %{name: "Updated Name", description: "Updated Description"}

      expected_result = %{
        id: service_account_id,
        name: "Updated Name",
        description: "Updated Description"
      }

      with_mock ServiceAccount, [:passthrough],
        update: fn id, params ->
          assert id == service_account_id
          assert params == update_params
          {:ok, expected_result}
        end do
        {:ok, result} = Actions.update(service_account_id, update_params)

        assert result == expected_result
      end
    end

    test "handles update failure" do
      service_account_id = "sa-id"
      update_params = %{name: "Updated Name", description: "Updated Description"}

      with_mock ServiceAccount, [:passthrough], update: fn _, _ -> {:error, :update_failed} end do
        {:error, :update_failed} = Actions.update(service_account_id, update_params)
      end
    end
  end

  describe "deactivate/1" do
    test "deactivates service account successfully" do
      service_account_id = "sa-id"

      with_mock ServiceAccount, [:passthrough],
        deactivate: fn id ->
          assert id == service_account_id
          {:ok, :deactivated}
        end do
        {:ok, :deactivated} = Actions.deactivate(service_account_id)
      end
    end

    test "handles deactivate failure" do
      service_account_id = "sa-id"

      with_mock ServiceAccount, [:passthrough],
        deactivate: fn _ -> {:error, :deactivate_failed} end do
        {:error, :deactivate_failed} = Actions.deactivate(service_account_id)
      end
    end
  end

  describe "reactivate/1" do
    test "reactivates service account successfully" do
      service_account_id = "sa-id"

      with_mock ServiceAccount, [:passthrough],
        reactivate: fn id ->
          assert id == service_account_id
          {:ok, :reactivated}
        end do
        {:ok, :reactivated} = Actions.reactivate(service_account_id)
      end
    end

    test "handles reactivate failure" do
      service_account_id = "sa-id"

      with_mock ServiceAccount, [:passthrough],
        reactivate: fn _ -> {:error, :reactivate_failed} end do
        {:error, :reactivate_failed} = Actions.reactivate(service_account_id)
      end
    end
  end

  describe "destroy/1" do
    test "destroys service account successfully" do
      service_account_id = "sa-id"

      with_mock ServiceAccount, [:passthrough],
        destroy: fn id ->
          assert id == service_account_id
          {:ok, :destroyed}
        end do
        {:ok, :destroyed} = Actions.destroy(service_account_id)
      end
    end

    test "handles destroy failure" do
      service_account_id = "sa-id"

      with_mock ServiceAccount, [:passthrough], destroy: fn _ -> {:error, :destroy_failed} end do
        {:error, :destroy_failed} = Actions.destroy(service_account_id)
      end
    end
  end

  describe "regenerate_token/1" do
    test "regenerates token successfully" do
      service_account_id = "sa-id"
      new_token = "new-token-123"

      with_mock ServiceAccount, [:passthrough],
        regenerate_token: fn id ->
          assert id == service_account_id
          {:ok, new_token}
        end do
        {:ok, result} = Actions.regenerate_token(service_account_id)

        assert result == new_token
      end
    end

    test "handles token regeneration failure" do
      service_account_id = "sa-id"

      with_mock ServiceAccount, [:passthrough],
        regenerate_token: fn _ -> {:error, :token_regeneration_failed} end do
        {:error, :token_regeneration_failed} = Actions.regenerate_token(service_account_id)
      end
    end
  end

  describe "list_by_org/2" do
    test "lists service accounts for organization" do
      org_id = "org-id"
      pagination_params = %{page_size: 10, page_token: nil}

      expected_result = %{
        service_accounts: [
          %{id: "sa-1", name: "SA 1"},
          %{id: "sa-2", name: "SA 2"}
        ],
        next_page_token: nil
      }

      with_mock ServiceAccount, [:passthrough],
        find_by_org: fn id, page_size, page_token ->
          assert id == org_id
          assert page_size == 10
          assert page_token == nil
          {:ok, expected_result}
        end do
        {:ok, result} = Actions.list_by_org(org_id, pagination_params)

        assert result == expected_result
      end
    end

    test "handles pagination parameters" do
      org_id = "org-id"
      pagination_params = %{page_size: 5, page_token: "token-123"}

      expected_result = %{
        service_accounts: [%{id: "sa-1", name: "SA 1"}],
        next_page_token: "token-456"
      }

      with_mock ServiceAccount, [:passthrough],
        find_by_org: fn id, page_size, page_token ->
          assert id == org_id
          assert page_size == 5
          assert page_token == "token-123"
          {:ok, expected_result}
        end do
        {:ok, result} = Actions.list_by_org(org_id, pagination_params)

        assert result == expected_result
      end
    end

    test "handles listing failure" do
      org_id = "org-id"
      pagination_params = %{page_size: 10, page_token: nil}

      with_mock ServiceAccount, [:passthrough],
        find_by_org: fn _, _, _ -> {:error, :listing_failed} end do
        {:error, :listing_failed} = Actions.list_by_org(org_id, pagination_params)
      end
    end
  end

  describe "integration tests" do
    defp setup_integration_mocks do
      [
        {Guard.Api.Organization, [:passthrough],
         [fetch: fn _ -> %InternalApi.Organization.Organization{org_username: "test-org"} end]},
        {Guard.FrontRepo.User, [:passthrough],
         [reset_auth_token: fn _ -> {:ok, "test-token"} end]},
        {Guard.Store.RbacUser, [:passthrough],
         [
           create: fn _, _, _, _ -> :ok end,
           fetch: fn _ -> %{id: "rbac-user-id"} end
         ]},
        {Guard.Api.Rbac, [:passthrough], [assign_role: fn _, _, _ -> :ok end]},
        {Guard.Events.UserCreated, [:passthrough], [publish: fn _, _ -> :ok end]}
      ]
    end

    test "full create flow with database" do
      with_mocks(setup_integration_mocks()) do
        params =
          ServiceAccountFactory.build_params_with_creator(
            name: "Integration Test SA",
            description: "Integration test description"
          )

        {:ok, %{service_account: service_account, api_token: api_token}} = Actions.create(params)

        assert service_account.name == "Integration Test SA"
        assert service_account.description == "Integration test description"
        assert service_account.org_id == params.org_id
        assert service_account.creator_id == params.creator_id
        assert service_account.deactivated == false
        assert is_binary(api_token)

        assert String.contains?(
                 service_account.email,
                 "@service-accounts.test-org.#{Application.fetch_env!(:guard, :base_domain)}"
               )

        # Verify event was published
        assert_called(Guard.Events.UserCreated.publish(service_account.id, false))
      end
    end

    test "full update flow with database" do
      with_mocks(setup_integration_mocks()) do
        # Create service account first
        params = ServiceAccountFactory.build_params_with_creator(name: "Original Name")
        {:ok, %{service_account: service_account, api_token: _}} = Actions.create(params)

        # Update it
        update_params = %{name: "Updated Name", description: "Updated Description"}
        {:ok, updated_sa} = Actions.update(service_account.id, update_params)

        assert updated_sa.name == "Updated Name"
        assert updated_sa.description == "Updated Description"
        assert updated_sa.id == service_account.id
      end
    end
  end
end
