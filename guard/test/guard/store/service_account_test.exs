defmodule Guard.Store.ServiceAccountTest do
  use Guard.RepoCase, async: false

  import Mock

  alias Guard.Store.ServiceAccount
  alias Guard.FrontRepo
  alias Guard.FrontRepo.User
  alias Support.Factories.ServiceAccountFactory

  setup do
    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()
    :ok
  end

  describe "find/1" do
    test "returns service account when found" do
      {:ok, %{service_account: created_sa}} = ServiceAccountFactory.insert()

      {:ok, found_sa} = ServiceAccount.find(created_sa.id)

      assert found_sa.id == created_sa.id
      assert found_sa.name == created_sa.user.name
      assert found_sa.description == created_sa.description
      assert found_sa.deactivated == false
    end

    test "returns error when service account not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ServiceAccount.find(non_existent_id)
    end

    test "returns error when service account is deactivated" do
      {:ok, %{service_account: created_sa, user: user}} = ServiceAccountFactory.insert()

      # Deactivate the user
      User.changeset(user, %{deactivated: true, deactivated_at: DateTime.utc_now()})
      |> FrontRepo.update()

      assert {:error, :not_found} = ServiceAccount.find(created_sa.id)
    end

    test "returns error when service account is blocked" do
      {:ok, %{service_account: created_sa, user: user}} = ServiceAccountFactory.insert()

      # Block the user
      User.changeset(user, %{blocked_at: DateTime.utc_now()})
      |> FrontRepo.update()

      assert {:error, :not_found} = ServiceAccount.find(created_sa.id)
    end

    test "returns error for invalid UUID" do
      assert {:error, :not_found} = ServiceAccount.find("invalid-uuid")
    end
  end

  describe "find_by_org/3" do
    test "returns service accounts for organization" do
      org_id = Ecto.UUID.generate()
      {:ok, %{service_account: sa1}} = ServiceAccountFactory.insert(org_id: org_id, name: "SA1")
      {:ok, %{service_account: sa2}} = ServiceAccountFactory.insert(org_id: org_id, name: "SA2")

      # Create service account in different org
      {:ok, %{service_account: _sa3}} = ServiceAccountFactory.insert(name: "SA3")

      {:ok, result} = ServiceAccount.find_by_org(org_id, 10, nil)

      assert length(result.service_accounts) == 2
      assert result.next_page_token == nil

      found_ids = Enum.map(result.service_accounts, & &1.id) |> Enum.sort()
      expected_ids = [sa1.id, sa2.id] |> Enum.sort()
      assert found_ids == expected_ids
    end

    test "returns empty list when no service accounts found" do
      org_id = Ecto.UUID.generate()

      {:ok, result} = ServiceAccount.find_by_org(org_id, 10, nil)

      assert result.service_accounts == []
      assert result.next_page_token == nil
    end

    test "handles pagination correctly" do
      org_id = Ecto.UUID.generate()

      # Create 3 service accounts
      for i <- 1..3 do
        {:ok, _} = ServiceAccountFactory.insert(org_id: org_id, name: "SA#{i}")
      end

      # Get first page with page_size 2
      {:ok, result} = ServiceAccount.find_by_org(org_id, 2, nil)

      assert length(result.service_accounts) == 2
      assert result.next_page_token == "2"

      # Get second page
      {:ok, result2} = ServiceAccount.find_by_org(org_id, 2, "2")

      assert length(result2.service_accounts) == 1
      assert result2.next_page_token == nil
    end

    test "filters out deactivated service accounts" do
      org_id = Ecto.UUID.generate()
      {:ok, %{service_account: sa1}} = ServiceAccountFactory.insert(org_id: org_id, name: "SA1")

      {:ok, %{service_account: _sa2, user: user2}} =
        ServiceAccountFactory.insert(org_id: org_id, name: "SA2")

      # Deactivate second service account
      User.changeset(user2, %{deactivated: true, deactivated_at: DateTime.utc_now()})
      |> FrontRepo.update()

      {:ok, result} = ServiceAccount.find_by_org(org_id, 10, nil)

      assert length(result.service_accounts) == 1
      assert List.first(result.service_accounts).id == sa1.id
    end

    test "returns error for invalid org_id" do
      assert {:error, :invalid_org_id} = ServiceAccount.find_by_org("invalid-uuid", 10, nil)
    end
  end

  describe "create/1" do
    test "creates service account successfully" do
      with_mocks([
        {Guard.Api.Organization, [:passthrough], [fetch: fn _ -> %{username: "test-org"} end]},
        {Guard.FrontRepo.User, [:passthrough],
         [reset_auth_token: fn _ -> {:ok, "plain-token"} end]}
      ]) do
        params = ServiceAccountFactory.build_params_with_creator(description: "test-description")

        {:ok, result} = ServiceAccount.create(params)

        assert result.api_token == "plain-token"
        assert result.service_account.name == params.name
        assert result.service_account.description == params.description
        assert result.service_account.org_id == params.org_id
        assert result.service_account.creator_id == params.creator_id
        assert result.service_account.deactivated == false

        assert String.contains?(
                 result.service_account.email,
                 "@sa.test-org.#{Application.fetch_env!(:guard, :base_domain)}"
               )
      end
    end

    test "creates user with correct service account fields" do
      with_mocks([
        {Guard.Api.Organization, [:passthrough], [fetch: fn _ -> %{username: "test-org"} end]},
        {Guard.FrontRepo.User, [:passthrough],
         [reset_auth_token: fn _ -> {:ok, "plain-token"} end]}
      ]) do
        params =
          ServiceAccountFactory.build_params_with_creator(
            name: "test-sa",
            org_id: Ecto.UUID.generate()
          )

        {:ok, result} = ServiceAccount.create(params)

        # Verify user was created with correct fields
        user = FrontRepo.get!(User, result.service_account.user_id)
        assert user.creation_source == :service_account
        assert user.single_org_user == true
        assert user.deactivated == false
        assert user.org_id == params.org_id
        assert user.name == params.name
      end
    end

    test "generates synthetic email correctly" do
      with_mocks([
        {Guard.Api.Organization, [:passthrough], [fetch: fn _ -> %{username: "MyOrg-123"} end]},
        {Guard.FrontRepo.User, [:passthrough],
         [reset_auth_token: fn _ -> {:ok, "plain-token"} end]}
      ]) do
        params = ServiceAccountFactory.build_params_with_creator(name: "My Service Account!")

        {:ok, result} = ServiceAccount.create(params)

        # Should sanitize both name and org username
        assert result.service_account.email ==
                 "my-service-account-@sa.myorg-123.#{Application.fetch_env!(:guard, :base_domain)}"
      end
    end

    test "handles organization fetch failure" do
      with_mocks([
        {Guard.Api.Organization, [:passthrough], [fetch: fn _ -> nil end]},
        {Guard.FrontRepo.User, [:passthrough],
         [reset_auth_token: fn _ -> {:ok, "plain-token"} end]}
      ]) do
        params = ServiceAccountFactory.build_params_with_creator(name: "test-sa")

        {:ok, result} = ServiceAccount.create(params)

        # Should use fallback email
        assert String.contains?(
                 result.service_account.email,
                 "@sa.unknown.#{Application.fetch_env!(:guard, :base_domain)}"
               )
      end
    end

    test "handles token generation failure" do
      with_mock Guard.FrontRepo.User, [:passthrough],
        reset_auth_token: fn _ -> {:error, :token_generation_failed} end do
        params = ServiceAccountFactory.build_params_with_creator()

        {:error, reason} = ServiceAccount.create(params)

        assert reason == :token_generation_failed
      end
    end

    test "handles user creation validation errors" do
      with_mocks([
        {Guard.Api.Organization, [:passthrough], [fetch: fn _ -> %{username: "test-org"} end]},
        {Guard.FrontRepo.User, [:passthrough],
         [reset_auth_token: fn _ -> {:ok, "plain-token"} end]}
      ]) do
        # Try to create with invalid email (too long)
        params = ServiceAccountFactory.build_params_with_creator(name: String.duplicate("a", 300))

        {:error, errors} = ServiceAccount.create(params)

        assert is_list(errors)
      end
    end
  end

  describe "update/2" do
    test "updates service account name and description" do
      {:ok, %{service_account: sa}} = ServiceAccountFactory.insert()

      update_params = %{name: "Updated Name", description: "Updated Description"}

      {:ok, updated_sa} = ServiceAccount.update(sa.id, update_params)

      assert updated_sa.user.name == "Updated Name"
      assert updated_sa.description == "Updated Description"
      assert updated_sa.id == sa.id
    end

    test "updates synthetic email when name changes" do
      with_mock Guard.Api.Organization, [:passthrough], fetch: fn _ -> %{username: "test-org"} end do
        {:ok, %{service_account: sa}} = ServiceAccountFactory.insert()

        update_params = %{name: "New Name"}

        {:ok, updated_sa} = ServiceAccount.update(sa.id, update_params)

        assert updated_sa.user.name == "New Name"

        assert String.contains?(
                 updated_sa.user.email,
                 "new-name@sa.test-org.#{Application.fetch_env!(:guard, :base_domain)}"
               )
      end
    end

    test "updates only description when name not provided" do
      {:ok, %{service_account: sa, user: user}} = ServiceAccountFactory.insert()
      original_name = user.name

      update_params = %{description: "New Description"}

      {:ok, updated_sa} = ServiceAccount.update(sa.id, update_params)

      assert updated_sa.user.name == original_name
      assert updated_sa.description == "New Description"
    end

    test "returns error when service account not found" do
      non_existent_id = Ecto.UUID.generate()

      {:error, :not_found} = ServiceAccount.update(non_existent_id, %{name: "New Name"})
    end

    test "returns error for invalid UUID" do
      assert {:error, :invalid_id} = ServiceAccount.update("invalid-uuid", %{name: "New Name"})
    end

    test "handles database errors gracefully" do
      {:ok, %{service_account: sa}} = ServiceAccountFactory.insert()

      # Mock a database error
      with_mock FrontRepo, [:passthrough], update: fn _ -> {:error, %Ecto.Changeset{}} end do
        assert {:error, []} = ServiceAccount.update(sa.id, %{name: "New Name"})
      end
    end
  end

  describe "delete/1" do
    test "soft deletes service account by deactivating user" do
      {:ok, %{service_account: sa}} = ServiceAccountFactory.insert()

      {:ok, :deleted} = ServiceAccount.delete(sa.id)

      # Verify user is deactivated
      user = FrontRepo.get!(User, sa.id)
      assert user.deactivated == true
      assert user.deactivated_at != nil

      # Verify service account is no longer findable
      assert {:error, :not_found} = ServiceAccount.find(sa.id)
    end

    test "returns error when service account not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ServiceAccount.delete(non_existent_id)
    end

    test "returns error for invalid UUID" do
      assert {:error, :invalid_id} = ServiceAccount.delete("invalid-uuid")
    end

    test "handles database errors gracefully" do
      {:ok, %{service_account: sa}} = ServiceAccountFactory.insert()

      # Mock a database error
      with_mock FrontRepo, [:passthrough], update: fn _ -> {:error, %Ecto.Changeset{}} end do
        assert {:error, :internal_error} = ServiceAccount.delete(sa.id)
      end
    end
  end

  describe "regenerate_token/1" do
    test "regenerates token successfully" do
      with_mock Guard.FrontRepo.User, [:passthrough],
        reset_auth_token: fn _ -> {:ok, "new-token"} end do
        {:ok, %{service_account: sa}} = ServiceAccountFactory.insert()

        {:ok, new_token} = ServiceAccount.regenerate_token(sa.id)

        assert new_token == "new-token"
      end
    end

    test "returns error when service account not found" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ServiceAccount.regenerate_token(non_existent_id)
    end

    test "returns error for invalid UUID" do
      assert {:error, :invalid_id} = ServiceAccount.regenerate_token("invalid-uuid")
    end

    test "handles token generation failure" do
      with_mock Guard.FrontRepo.User, [:passthrough],
        reset_auth_token: fn _ -> {:error, :token_error} end do
        {:ok, %{service_account: sa}} = ServiceAccountFactory.insert()

        {:error, :token_error} = ServiceAccount.regenerate_token(sa.id)
      end
    end

    test "handles database errors gracefully" do
      {:ok, %{service_account: sa}} = ServiceAccountFactory.insert()

      # Mock a database error during token update
      with_mocks([
        {Guard.FrontRepo.User, [:passthrough],
         [reset_auth_token: fn _ -> {:ok, "new-token"} end]},
        {FrontRepo, [:passthrough], [update: fn _ -> {:error, %Ecto.Changeset{}} end]}
      ]) do
        assert {:error, []} = ServiceAccount.regenerate_token(sa.id)
      end
    end
  end
end
