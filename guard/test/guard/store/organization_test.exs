defmodule Guard.Store.OrganizationTest do
  use Guard.RepoCase, async: true
  doctest Guard.Store.Organization

  alias Guard.Store.Organization
  alias Support.Factories
  alias Guard.FrontRepo

  setup do
    FrontRepo.delete_all(FrontRepo.Organization)

    organization = Support.Factories.Organization.insert!(username: "test-org-0")

    [
      org_id: organization.id
    ]
  end

  describe "exists?" do
    test "checks if organization exists", %{org_id: org_id} do
      assert Organization.exists?(org_id)
      refute Organization.exists?(Ecto.UUID.generate())
    end
  end

  describe "no_of_members" do
    test "counts number of members correctly", %{org_id: org_id} do
      list_members_response =
        InternalApi.RBAC.ListMembersResponse.new(
          members: [
            InternalApi.RBAC.ListMembersResponse.Member.new(
              subject:
                InternalApi.RBAC.Subject.new(
                  subject_id: Ecto.UUID.generate(),
                  subject_type: InternalApi.RBAC.SubjectType.value(:USER),
                  display_name: "John Doe"
                ),
              subject_role_bindings: [
                InternalApi.RBAC.SubjectRoleBinding.new(
                  role: InternalApi.RBAC.Role.new(id: Ecto.UUID.generate()),
                  org_id: org_id
                )
              ]
            ),
            InternalApi.RBAC.ListMembersResponse.Member.new(
              subject:
                InternalApi.RBAC.Subject.new(
                  subject_id: Ecto.UUID.generate(),
                  subject_type: InternalApi.RBAC.SubjectType.value(:USER),
                  display_name: "John Doe"
                ),
              subject_role_bindings: [
                InternalApi.RBAC.SubjectRoleBinding.new(
                  role: InternalApi.RBAC.Role.new(id: Ecto.UUID.generate()),
                  org_id: org_id
                )
              ]
            )
          ]
        )

      FunRegistry.set!(Support.Fake.RbacService, :list_members, list_members_response)

      assert Organization.no_of_members(org_id) == 2
    end
  end

  describe "list" do
    setup do
      FrontRepo.delete_all(FrontRepo.Organization)

      # Create organizations with different names and creation times
      now = DateTime.utc_now()

      org1 =
        Factories.Organization.insert!(
          name: "Alpha Org",
          username: "alpha-org",
          created_at: DateTime.add(now, -2, :day) |> DateTime.truncate(:second)
        )

      org2 =
        Factories.Organization.insert!(
          name: "Beta Org",
          username: "beta-org",
          created_at: DateTime.add(now, -1, :day) |> DateTime.truncate(:second)
        )

      org3 =
        Factories.Organization.insert!(
          name: "Charlie Org",
          username: "charlie-org",
          created_at: now |> DateTime.truncate(:second)
        )

      [orgs: [org1, org2, org3], now: now]
    end

    test "lists organizations ordered by name", %{orgs: [org1, org2, org3]} do
      {:ok, %{organizations: organizations}} =
        Organization.list(%{created_at_gt: :skip}, %{
          page_size: 10,
          page_token: nil,
          order: :BY_NAME_ASC
        })

      assert length(organizations) == 3
      assert Enum.map(organizations, & &1.name) == [org1.name, org2.name, org3.name]
    end

    test "lists organizations with pagination by name", %{orgs: [org1, org2, org3]} do
      # First page
      {:ok, %{organizations: first_page, next_page_token: next_token}} =
        Organization.list(%{created_at_gt: :skip}, %{
          page_size: 2,
          page_token: nil,
          order: :BY_NAME_ASC
        })

      assert length(first_page) == 2
      assert Enum.map(first_page, & &1.name) == [org1.name, org2.name]
      assert next_token != ""

      # Second page
      {:ok, %{organizations: second_page}} =
        Organization.list(%{created_at_gt: :skip}, %{
          page_size: 2,
          page_token: next_token,
          order: :BY_NAME_ASC
        })

      assert length(second_page) == 1
      assert Enum.map(second_page, & &1.name) == [org3.name]
    end

    test "lists organizations ordered by creation time", %{orgs: [org1, org2, org3]} do
      {:ok, %{organizations: organizations}} =
        Organization.list(%{created_at_gt: :skip}, %{
          page_size: 10,
          page_token: nil,
          order: :BY_CREATION_TIME_ASC
        })

      assert length(organizations) == 3
      assert Enum.map(organizations, & &1.name) == [org1.name, org2.name, org3.name]
    end

    test "filters organizations by creation time", %{now: now, orgs: [_, org2, org3]} do
      one_day_ago = DateTime.add(now, -25, :hour)

      {:ok, %{organizations: organizations}} =
        Organization.list(%{created_at_gt: one_day_ago}, %{
          page_size: 10,
          page_token: nil,
          order: :BY_NAME_ASC
        })

      assert length(organizations) == 2
      assert Enum.map(organizations, & &1.name) == [org2.name, org3.name]
    end

    test "handles empty result set" do
      FrontRepo.delete_all(FrontRepo.Organization)

      {:ok, %{organizations: organizations}} =
        Organization.list(%{created_at_gt: :skip}, %{
          page_size: 10,
          page_token: nil,
          order: :BY_NAME_ASC
        })

      assert organizations == []
    end
  end

  describe "list_by_ids" do
    test "returns organizations for given ids" do
      org1 = Support.Factories.Organization.insert!(username: "test-org-1")
      org2 = Support.Factories.Organization.insert!(username: "test-org-2")
      org3 = Support.Factories.Organization.insert!(username: "test-org-3")

      # Test fetching subset of organizations
      organizations = Organization.list_by_ids([org1.id, org2.id])
      assert length(organizations) == 2
      assert Enum.map(organizations, & &1.id) |> Enum.sort() == [org1.id, org2.id] |> Enum.sort()

      # Test fetching all organizations
      organizations = Organization.list_by_ids([org1.id, org2.id, org3.id])
      assert length(organizations) == 3

      assert Enum.map(organizations, & &1.id) |> Enum.sort() ==
               [org1.id, org2.id, org3.id] |> Enum.sort()

      # Test with non-existent IDs
      organizations = Organization.list_by_ids([org1.id, Ecto.UUID.generate()])
      assert length(organizations) == 1
      assert List.first(organizations).id == org1.id

      # Test with empty list
      assert Organization.list_by_ids([]) == []
    end
  end

  describe "get_by_id/1" do
    test "returns organization by id" do
      organization = Support.Factories.Organization.insert!()
      assert Organization.get_by_id(organization.id) == {:ok, organization}
    end

    test "returns nil for non-existent organization" do
      org_id = Ecto.UUID.generate()
      {:error, {:not_found, message}} = Organization.get_by_id(org_id)
      assert message == "Organization '#{org_id}' not found."
    end
  end

  describe "add_suspension/2" do
    test "creates suspension with valid params" do
      organization = Support.Factories.Organization.insert!(verified: true, suspended: false)
      refute organization.suspended
      assert organization.verified

      params = %{
        reason: :INSUFFICIENT_FUNDS,
        origin: "billing",
        description: "Account has insufficient funds"
      }

      assert {:ok, suspension} = Organization.add_suspension(organization, params)

      assert suspension.organization_id == organization.id
      assert suspension.reason == :INSUFFICIENT_FUNDS
      assert suspension.origin == "billing"
      assert suspension.description == "Account has insufficient funds"
      assert suspension.deleted_at == nil

      # Verify organization is suspended
      organization = FrontRepo.get!(FrontRepo.Organization, organization.id)
      assert organization.suspended
      assert organization.verified
    end

    test "sets organization as unverified when suspended for TOS violation" do
      organization = Support.Factories.Organization.insert!(verified: true, suspended: true)

      assert organization.suspended
      assert organization.verified

      params = %{
        reason: :VIOLATION_OF_TOS,
        origin: "compliance",
        description: "Terms of service violation"
      }

      assert {:ok, suspension} = Organization.add_suspension(organization, params)

      assert suspension.organization_id == organization.id
      assert suspension.reason == :VIOLATION_OF_TOS

      # Verify organization is suspended and unverified
      organization = FrontRepo.get!(FrontRepo.Organization, organization.id)
      assert organization.suspended
      refute organization.verified
    end

    test "returns existing suspension if one exists with same reason" do
      organization = Support.Factories.Organization.insert!()

      params = %{
        reason: :INSUFFICIENT_FUNDS,
        origin: "billing",
        description: "Account has insufficient funds"
      }

      assert {:ok, suspension1} = Organization.add_suspension(organization, params)
      assert {:ok, suspension2} = Organization.add_suspension(organization, params)
      assert suspension1.id == suspension2.id
    end
  end

  describe "remove_suspension/2" do
    test "removes suspension and marks organization as not suspended when it was the last suspension" do
      organization = Support.Factories.Organization.insert!(suspended: true)
      suspension = Support.Factories.Organization.insert_suspension!(organization.id)

      assert organization.suspended

      assert {:ok, removed_suspension} =
               Organization.remove_suspension(organization, suspension.reason)

      assert removed_suspension.id == suspension.id
      assert not is_nil(removed_suspension.deleted_at)

      # Verify organization is no longer suspended
      organization = FrontRepo.get!(FrontRepo.Organization, organization.id)
      refute organization.suspended
    end

    test "removes suspension but keeps organization suspended when there are other active suspensions" do
      organization = Support.Factories.Organization.insert!(suspended: true)

      suspension1 =
        Support.Factories.Organization.insert_suspension!(organization.id,
          reason: :INSUFFICIENT_FUNDS
        )

      _suspension2 =
        Support.Factories.Organization.insert_suspension!(organization.id,
          reason: :VIOLATION_OF_TOS
        )

      assert organization.suspended

      assert {:ok, removed_suspension} =
               Organization.remove_suspension(organization, suspension1.reason)

      assert removed_suspension.id == suspension1.id
      assert not is_nil(removed_suspension.deleted_at)

      # Verify organization is still suspended due to other active suspension
      organization = FrontRepo.get!(FrontRepo.Organization, organization.id)
      assert organization.suspended
    end

    test "marks organization as verified when removing VIOLATION_OF_TOS suspension" do
      organization = Support.Factories.Organization.insert!(suspended: true, verified: false)

      suspension =
        Support.Factories.Organization.insert_suspension!(organization.id,
          reason: :VIOLATION_OF_TOS
        )

      assert {:ok, removed_suspension} =
               Organization.remove_suspension(organization, suspension.reason)

      assert removed_suspension.id == suspension.id
      assert not is_nil(removed_suspension.deleted_at)

      # Verify organization is now verified
      organization = FrontRepo.get!(FrontRepo.Organization, organization.id)
      assert organization.verified
    end

    test "returns error when no active suspension exists with given reason" do
      organization = Support.Factories.Organization.insert!()

      assert {:error, :suspension_not_found} =
               Organization.remove_suspension(organization, :INSUFFICIENT_FUNDS)
    end

    test "returns error when suspension was already removed" do
      organization = Support.Factories.Organization.insert!(suspended: true)

      suspension =
        Support.Factories.Organization.insert_suspension!(
          organization.id,
          reason: :INSUFFICIENT_FUNDS,
          deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert {:error, :suspension_not_found} =
               Organization.remove_suspension(organization, suspension.reason)
    end
  end

  describe "modify_settings" do
    test "creates new settings for organization", %{org_id: org_id} do
      organization = FrontRepo.get!(FrontRepo.Organization, org_id)
      assert organization.settings == nil || organization.settings == %{}

      {:ok, updated_org} =
        Organization.modify_settings(organization, %{
          "theme" => "dark",
          "language" => "en"
        })

      assert updated_org.settings["theme"] == "dark"
      assert updated_org.settings["language"] == "en"

      # Verify persistence
      reloaded_org = FrontRepo.get!(FrontRepo.Organization, org_id)
      assert reloaded_org.settings["theme"] == "dark"
      assert reloaded_org.settings["language"] == "en"
    end

    test "updates existing settings", %{org_id: org_id} do
      organization = FrontRepo.get!(FrontRepo.Organization, org_id)

      # First create initial settings
      {:ok, org_with_settings} =
        Organization.modify_settings(organization, %{
          "theme" => "light",
          "language" => "en"
        })

      assert org_with_settings.settings["theme"] == "light"
      assert org_with_settings.settings["language"] == "en"

      # Now update settings
      {:ok, updated_org} =
        Organization.modify_settings(org_with_settings, %{
          "theme" => "dark",
          "notifications" => "all"
        })

      # Verify updates and existing values
      assert updated_org.settings["theme"] == "dark"
      assert updated_org.settings["language"] == "en"
      assert updated_org.settings["notifications"] == "all"

      # Verify persistence
      reloaded_org = FrontRepo.get!(FrontRepo.Organization, org_id)
      assert reloaded_org.settings["theme"] == "dark"
      assert reloaded_org.settings["language"] == "en"
      assert reloaded_org.settings["notifications"] == "all"
    end

    test "removes settings with empty values", %{org_id: org_id} do
      organization = FrontRepo.get!(FrontRepo.Organization, org_id)

      # First create initial settings
      {:ok, org_with_settings} =
        Organization.modify_settings(organization, %{
          "theme" => "light",
          "language" => "en",
          "notifications" => "all"
        })

      # Now update with empty values
      {:ok, updated_org} =
        Organization.modify_settings(org_with_settings, %{
          "theme" => "",
          "notifications" => nil
        })

      # Verify removals and remaining values
      refute Map.has_key?(updated_org.settings, "theme")
      refute Map.has_key?(updated_org.settings, "notifications")
      assert updated_org.settings["language"] == "en"

      # Verify persistence
      reloaded_org = FrontRepo.get!(FrontRepo.Organization, org_id)
      refute Map.has_key?(reloaded_org.settings, "theme")
      refute Map.has_key?(reloaded_org.settings, "notifications")
      assert reloaded_org.settings["language"] == "en"
    end

    test "handles nil settings map", %{org_id: org_id} do
      organization = FrontRepo.get!(FrontRepo.Organization, org_id)
      assert organization.settings == nil

      {:ok, updated_org} =
        Organization.modify_settings(organization, %{
          "theme" => "dark"
        })

      assert updated_org.settings["theme"] == "dark"
    end

    test "handles empty settings map", %{org_id: org_id} do
      organization = FrontRepo.get!(FrontRepo.Organization, org_id)
      {:ok, org_with_empty_settings} = Organization.modify_settings(organization, %{})
      assert org_with_empty_settings.settings == %{}

      {:ok, updated_org} =
        Organization.modify_settings(org_with_empty_settings, %{
          "theme" => "dark"
        })

      assert updated_org.settings["theme"] == "dark"
    end
  end

  describe "validate/1" do
    test "returns :ok for valid organization attributes" do
      attrs = %{
        name: "Test Organization",
        username: "test-org",
        creator_id: Ecto.UUID.generate()
      }

      assert :ok = Organization.validate(attrs)
    end

    test "returns error for invalid organization attributes" do
      attrs = %{
        name: "",
        username: "invalid username",
        creator_id: nil
      }

      assert {:error, errors} = Organization.validate(attrs)
      errors = Jason.decode!(errors)
      assert errors["name"] == ["Cannot be empty"]
      assert errors["creator_id"] == ["Cannot be empty"]

      assert errors["username"] == [
               "Use min. 3 characters, only lowercase letters a-z, numbers 0-9 and dash, no spaces."
             ]
    end

    test "returns error for restricted username" do
      attrs = %{
        name: "Test Organization",
        username: "domain1",
        creator_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = Organization.validate(attrs)
      errors = Jason.decode!(errors)
      assert errors["username"] == ["Already taken"]
    end

    test "returns error for existing username", %{org_id: org_id} do
      organization = FrontRepo.get!(FrontRepo.Organization, org_id)

      attrs = %{
        name: "Test Organization",
        username: organization.username,
        creator_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = Organization.validate(attrs)
      errors = Jason.decode!(errors)
      assert errors["username"] == ["Already taken"]
    end

    test "returns error for username longer than 62 characters" do
      attrs = %{
        name: "Test Organization",
        username: String.duplicate("a", 63),
        creator_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = Organization.validate(attrs)
      errors = Jason.decode!(errors)
      assert errors["username"] == ["Too long"]
    end
  end

  describe "destroy/1" do
    test "deletes organization when it exists", %{org_id: org_id} do
      organization = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, org_id)

      contact = Support.Factories.Organization.insert_contact!(organization.id)
      suspension = Support.Factories.Organization.insert_suspension!(organization.id)

      assert {:ok, deleted_org} = Organization.destroy(organization)
      assert deleted_org.id == org_id

      assert is_nil(Guard.FrontRepo.get(Guard.FrontRepo.Organization, org_id))
      assert is_nil(Guard.FrontRepo.get(Guard.FrontRepo.OrganizationContact, contact.id))
      assert is_nil(Guard.FrontRepo.get(Guard.FrontRepo.OrganizationSuspension, suspension.id))
    end
  end

  describe "create/1" do
    test "creates organization with valid attributes" do
      owner_id = Ecto.UUID.generate()

      attrs = %{
        name: "Test Organization",
        username: "test-org",
        creator_id: owner_id
      }

      assert {:ok, organization} = Organization.create(attrs)
      assert organization.name == "Test Organization"
      assert organization.username == "test-org"
      assert organization.creator_id == owner_id
    end

    test "returns error with invalid attributes" do
      attrs = %{
        name: "",
        username: "cc",
        creator_id: ""
      }

      assert {:error, changeset} = Organization.create(attrs)

      errors =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        |> Enum.map_join(", ", fn {key, msgs} -> "#{key}: #{Enum.join(msgs, ", ")}" end)

      assert errors ==
               "creator_id: Cannot be empty, name: Cannot be empty, username: Use min. 3 characters, only lowercase letters a-z, numbers 0-9 and dash, no spaces."
    end

    test "returns error when username is taken" do
      org = Support.Factories.Organization.insert!(username: "test-org")

      attrs = %{
        name: "Another Organization",
        username: org.username,
        creator_id: Ecto.UUID.generate()
      }

      assert {:error, changeset} = Organization.create(attrs)

      errors =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        |> Enum.map_join(", ", fn {key, msgs} -> "#{key}: #{Enum.join(msgs, ", ")}" end)

      assert errors == "username: Already taken"
    end
  end

  describe "update/2" do
    test "updates organization with valid attributes" do
      organization = Support.Factories.Organization.insert!(deny_non_member_workflows: false)

      attrs = %{
        name: "Updated Organization",
        username: "updated-org",
        deny_non_member_workflows: true,
        ip_allow_list: "192.168.1.1"
      }

      assert {:ok, updated_org} = Organization.update(organization, attrs)
      assert updated_org.name == "Updated Organization"
      assert updated_org.username == "updated-org"
      assert updated_org.deny_non_member_workflows == true
      assert updated_org.ip_allow_list == "192.168.1.1"
    end

    test "updates organization with empty ip_allow_list" do
      organization = Support.Factories.Organization.insert!(deny_non_member_workflows: false)

      attrs = %{
        name: "Updated Organization",
        username: "updated-org",
        deny_non_member_workflows: true,
        ip_allow_list: ""
      }

      assert {:ok, updated_org} = Organization.update(organization, attrs)
      assert updated_org.name == "Updated Organization"
      assert updated_org.username == "updated-org"
      assert updated_org.deny_non_member_workflows == true
      assert updated_org.ip_allow_list == ""
    end

    test "returns error with invalid attributes" do
      organization = Support.Factories.Organization.insert!()

      attrs = %{
        name: "",
        username: "cc"
      }

      assert {:error, changeset} = Organization.update(organization, attrs)

      errors =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        |> Enum.map_join(", ", fn {key, msgs} -> "#{key}: #{Enum.join(msgs, ", ")}" end)

      assert errors ==
               "name: Cannot be empty, username: Use min. 3 characters, only lowercase letters a-z, numbers 0-9 and dash, no spaces."
    end

    test "returns error when username is taken" do
      existing_org = Support.Factories.Organization.insert!(username: "taken-username")
      organization = Support.Factories.Organization.insert!()

      attrs = %{username: existing_org.username}

      assert {:error, changeset} = Organization.update(organization, attrs)

      errors =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
        |> Enum.map_join(", ", fn {key, msgs} -> "#{key}: #{Enum.join(msgs, ", ")}" end)

      assert errors == "username: Already taken"
    end
  end
end
