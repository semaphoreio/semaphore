defmodule Guard.FrontRepo.ServiceAccountTest do
  use Guard.RepoCase, async: true

  alias Guard.FrontRepo
  alias Guard.FrontRepo.{ServiceAccount, User}

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        description: "Test service account description",
        creator_id: user.id
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      assert changeset.valid?
      assert changeset.changes.id == user.id
      assert changeset.changes.description == "Test service account description"
      assert changeset.changes.creator_id == attrs.creator_id
    end

    test "creates valid changeset with minimal required fields" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        creator_id: user.id
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      assert changeset.valid?
      assert changeset.changes.id == user.id
    end

    test "sets id to match user id" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        description: "Test description",
        creator_id: user.id
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      assert changeset.valid?
      assert changeset.changes.id == user.id
    end

    test "requires id field" do
      attrs = %{
        description: "Test description"
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:id]
    end

    test "requires creator_id field" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        description: "Test description"
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:creator_id]
    end

    test "validates description length" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        creator_id: user.id,
        # Exceeds 500 character limit
        description: String.duplicate("a", 501)
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      refute changeset.valid?
      assert {"Description cannot exceed 500 characters", _} = changeset.errors[:description]
    end

    test "allows description up to 500 characters" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        creator_id: user.id,
        # Exactly 500 characters
        description: String.duplicate("a", 500)
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      assert changeset.valid?
    end

    test "allows empty description" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        creator_id: user.id,
        description: ""
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      assert changeset.valid?
    end

    test "allows nil description" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        creator_id: user.id,
        description: nil
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      assert changeset.valid?
    end

    test "enforces foreign key constraint on id" do
      non_existent_user_id = Ecto.UUID.generate()
      creator_user = create_test_user()

      attrs = %{
        id: non_existent_user_id,
        creator_id: creator_user.id,
        description: "Test description"
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)

      # Changeset should be valid, but insertion should fail
      assert changeset.valid?

      {:error, changeset} = FrontRepo.insert(changeset)
      assert {"does not exist", _} = changeset.errors[:id]
    end

    test "enforces unique constraint on id" do
      user = create_test_user()
      creator_user = create_test_user()

      # Create first service account
      attrs1 = %{
        id: user.id,
        creator_id: creator_user.id,
        description: "First service account"
      }

      changeset1 = ServiceAccount.changeset(%ServiceAccount{}, attrs1)
      {:ok, _} = FrontRepo.insert(changeset1)

      # Try to create second service account with same id
      attrs2 = %{
        id: user.id,
        creator_id: creator_user.id,
        description: "Second service account"
      }

      changeset2 = ServiceAccount.changeset(%ServiceAccount{}, attrs2)

      # Changeset should be valid, but insertion should fail
      assert changeset2.valid?

      {:error, changeset} = FrontRepo.insert(changeset2)
      assert {"has already been taken", _} = changeset.errors[:id]
    end
  end

  describe "update_changeset/2" do
    test "updates description successfully" do
      user = create_test_user()
      service_account = create_test_service_account(user)

      attrs = %{
        description: "Updated description"
      }

      changeset = ServiceAccount.update_changeset(service_account, attrs)

      assert changeset.valid?
      assert changeset.changes.description == "Updated description"
    end

    test "validates description length on update" do
      user = create_test_user()
      service_account = create_test_service_account(user)

      attrs = %{
        # Exceeds 500 character limit
        description: String.duplicate("a", 501)
      }

      changeset = ServiceAccount.update_changeset(service_account, attrs)

      refute changeset.valid?
      assert {"Description cannot exceed 500 characters", _} = changeset.errors[:description]
    end

    test "allows empty description on update" do
      user = create_test_user()
      service_account = create_test_service_account(user)

      attrs = %{
        description: ""
      }

      changeset = ServiceAccount.update_changeset(service_account, attrs)

      assert changeset.valid?
    end

    test "does not allow updating id" do
      user = create_test_user()
      service_account = create_test_service_account(user)
      another_user = create_test_user()

      attrs = %{
        id: another_user.id,
        description: "Updated description"
      }

      changeset = ServiceAccount.update_changeset(service_account, attrs)

      # id should not be in the changeset changes
      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :id)
      assert changeset.changes.description == "Updated description"
    end

    test "does not allow updating creator_id" do
      user = create_test_user()
      service_account = create_test_service_account(user)
      new_creator_id = Ecto.UUID.generate()

      attrs = %{
        creator_id: new_creator_id,
        description: "Updated description"
      }

      changeset = ServiceAccount.update_changeset(service_account, attrs)

      # creator_id should not be in the changeset changes
      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :creator_id)
      assert changeset.changes.description == "Updated description"
    end
  end

  describe "schema associations" do
    test "belongs_to user relationship" do
      user = create_test_user()
      service_account = create_test_service_account(user)

      # Load the association
      service_account = FrontRepo.preload(service_account, :user)

      assert service_account.user.id == user.id
      assert service_account.user.email == user.email
    end

    test "cascade delete when user is deleted" do
      user = create_test_user()
      service_account = create_test_service_account(user)

      # Delete the user
      FrontRepo.delete(user)

      # Service account should be deleted as well
      assert FrontRepo.get(ServiceAccount, service_account.id) == nil
    end
  end

  describe "schema fields" do
    test "has correct field types" do
      user = create_test_user()
      service_account = create_test_service_account(user)

      assert is_binary(service_account.id)
      assert is_binary(service_account.creator_id)
      assert is_binary(service_account.description) or is_nil(service_account.description)
    end

    test "id is primary key" do
      user = create_test_user()

      attrs = %{
        id: user.id,
        creator_id: user.id,
        description: "Test description"
      }

      changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)
      {:ok, service_account} = FrontRepo.insert(changeset)

      assert service_account.id == user.id
      assert FrontRepo.get(ServiceAccount, user.id) == service_account
    end
  end

  # Helper functions

  defp create_test_user do
    # Generate a unique suffix using current timestamp in microseconds + random number
    # This ensures better test isolation by making each user truly unique
    timestamp = System.system_time(:microsecond)
    random_suffix = :rand.uniform(999_999)
    unique_suffix = "#{timestamp}-#{random_suffix}"

    user_attrs = %{
      id: Ecto.UUID.generate(),
      email: "test-#{unique_suffix}@example.com",
      name: "Test User #{unique_suffix}",
      org_id: Ecto.UUID.generate(),
      creation_source: :service_account,
      single_org_user: true,
      company: "",
      deactivated: false
    }

    changeset = User.changeset(%User{}, user_attrs)
    {:ok, user} = FrontRepo.insert(changeset)
    user
  end

  defp create_test_service_account(user) do
    # Create a creator user to satisfy foreign key constraint
    creator_user = create_test_user()

    attrs = %{
      id: user.id,
      description: "Test service account description",
      creator_id: creator_user.id
    }

    changeset = ServiceAccount.changeset(%ServiceAccount{}, attrs)
    {:ok, service_account} = FrontRepo.insert(changeset)
    service_account
  end
end
