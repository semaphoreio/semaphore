defmodule Guard.GrpcServers.OrganizationServerTest do
  use Guard.RepoCase, async: false

  import Mock

  alias InternalApi.Organization
  alias InternalApi.Organization.OrganizationService.Stub

  setup do
    organization = Support.Factories.Organization.insert!(username: "test-org-0")
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    %{grpc_channel: channel, organization: organization}
  end

  describe "describe" do
    test "returns an organization by id", %{grpc_channel: channel, organization: organization} do
      request = Organization.DescribeRequest.new(org_id: organization.id)

      {:ok, response} =
        channel
        |> Stub.describe(request)

      id = organization.id
      username = organization.username

      assert %Organization.DescribeResponse{
               organization: %Organization.Organization{
                 org_id: ^id,
                 org_username: ^username
               }
             } = response
    end

    test "returns an organization by username", %{
      grpc_channel: channel,
      organization: organization
    } do
      request = Organization.DescribeRequest.new(org_username: organization.username)

      {:ok, response} =
        channel
        |> Stub.describe(request)

      id = organization.id
      username = organization.username

      assert %Organization.DescribeResponse{
               organization: %Organization.Organization{
                 org_id: ^id,
                 org_username: ^username
               }
             } = response
    end

    test "returns a soft-deleted organization by id if soft_deleted param is true", %{
      grpc_channel: channel,
      organization: organization
    } do
      {:ok, organization} = Guard.Store.Organization.soft_destroy(organization)

      request = Organization.DescribeRequest.new(org_id: organization.id, soft_deleted: true)

      {:ok, response} =
        channel
        |> Stub.describe(request)

      id = organization.id
      username = organization.username

      assert %Organization.DescribeResponse{
               organization: %Organization.Organization{
                 org_id: ^id,
                 org_username: ^username
               }
             } = response
    end

    test "returns a soft-deleted organization by username if soft_deleted param is true", %{
      grpc_channel: channel,
      organization: organization
    } do
      {:ok, organization} = Guard.Store.Organization.soft_destroy(organization)

      request =
        Organization.DescribeRequest.new(org_username: organization.username, soft_deleted: true)

      {:ok, response} =
        channel
        |> Stub.describe(request)

      id = organization.id
      username = organization.username

      assert %Organization.DescribeResponse{
               organization: %Organization.Organization{
                 org_id: ^id,
                 org_username: ^username
               }
             } = response
    end

    test "returns an error if the organization is not found", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()
      request = Organization.DescribeRequest.new(org_id: org_id)

      assert {:error, %GRPC.RPCError{message: message}} = Stub.describe(channel, request)

      assert message =~ "Organization '#{org_id}' not found."
    end

    test "returns an error if the organization is soft deleted and soft_deleted is false", %{
      grpc_channel: channel,
      organization: organization
    } do
      {:ok, organization} = Guard.Store.Organization.soft_destroy(organization)

      request = Organization.DescribeRequest.new(org_id: organization.id, soft_deleted: false)

      assert {:error, %GRPC.RPCError{message: message, status: status}} =
               Stub.describe(channel, request)

      assert status == GRPC.Status.not_found()
      assert message =~ "Organization '#{organization.id}' not found."
    end

    test "returns an error if the organization is not soft deleted and soft_deleted is true", %{
      grpc_channel: channel,
      organization: organization
    } do
      request = Organization.DescribeRequest.new(org_id: organization.id, soft_deleted: true)

      assert {:error, %GRPC.RPCError{message: message, status: status}} =
               Stub.describe(channel, request)

      assert status == GRPC.Status.not_found()
      assert message =~ "Organization '#{organization.id}' not found."
    end
  end

  describe "describe_many" do
    test "returns multiple organizations by ids", %{grpc_channel: channel} do
      org1 = Support.Factories.Organization.insert!(name: "A", username: "abc")
      org2 = Support.Factories.Organization.insert!(name: "B", username: "bcd")

      request = Organization.DescribeManyRequest.new(org_ids: [org1.id, org2.id])

      {:ok, response} =
        channel
        |> Stub.describe_many(request)

      assert length(response.organizations) == 2

      [resp_org1, resp_org2] = Enum.sort_by(response.organizations, & &1.name)
      assert resp_org1.org_id == org1.id
      assert resp_org1.org_username == org1.username
      assert resp_org2.org_id == org2.id
      assert resp_org2.org_username == org2.username
    end

    test "filters soft-deleted organizations if soft_deleted param is false", %{
      grpc_channel: channel
    } do
      org1 = Support.Factories.Organization.insert!(name: "A", username: "abc")
      org2 = Support.Factories.Organization.insert!(name: "B", username: "bcd")
      org3 = Support.Factories.Organization.insert!(name: "C", username: "cde")
      {:ok, _} = Guard.Store.Organization.soft_destroy(org3)

      request =
        Organization.DescribeManyRequest.new(
          org_ids: [org1.id, org2.id, org3.id],
          soft_deleted: false
        )

      {:ok, response} =
        channel
        |> Stub.describe_many(request)

      assert length(response.organizations) == 2
    end

    test "returns soft-deleted organizations if soft_deleted param is true", %{
      grpc_channel: channel
    } do
      org1 = Support.Factories.Organization.insert!(name: "A", username: "abc")
      org2 = Support.Factories.Organization.insert!(name: "B", username: "bcd")
      org3 = Support.Factories.Organization.insert!(name: "C", username: "cde")
      {:ok, _} = Guard.Store.Organization.soft_destroy(org3)

      request =
        Organization.DescribeManyRequest.new(
          org_ids: [org1.id, org2.id, org3.id],
          soft_deleted: true
        )

      {:ok, response} =
        channel
        |> Stub.describe_many(request)

      assert length(response.organizations) == 1
    end

    test "filters out invalid UUIDs", %{grpc_channel: channel, organization: organization} do
      request = Organization.DescribeManyRequest.new(org_ids: [organization.id, "not-a-uuid"])

      {:ok, response} =
        channel
        |> Stub.describe_many(request)

      assert length(response.organizations) == 1
      [org] = response.organizations
      assert org.org_id == organization.id
      assert org.org_username == organization.username
    end

    test "handles non-existent organizations", %{
      grpc_channel: channel,
      organization: organization
    } do
      non_existent_id = Ecto.UUID.generate()
      request = Organization.DescribeManyRequest.new(org_ids: [organization.id, non_existent_id])

      {:ok, response} =
        channel
        |> Stub.describe_many(request)

      assert length(response.organizations) == 1
      [org] = response.organizations
      assert org.org_id == organization.id
    end

    test "handles empty list of ids", %{grpc_channel: channel} do
      request = Organization.DescribeManyRequest.new(org_ids: [])

      {:ok, response} =
        channel
        |> Stub.describe_many(request)

      assert response.organizations == []
    end
  end

  describe "fetch_organization_settings" do
    test "returns organization settings when organization exists", %{
      grpc_channel: channel,
      organization: organization
    } do
      # Update organization with some settings
      {:ok, organization} =
        Guard.Store.Organization.update(organization, %{
          settings: %{
            "key1" => "value1",
            "key2" => "value2"
          }
        })

      request = Organization.FetchOrganizationSettingsRequest.new(org_id: organization.id)

      {:ok, response} =
        channel
        |> Stub.fetch_organization_settings(request)

      assert %Organization.FetchOrganizationSettingsResponse{
               settings: settings
             } = response

      assert length(settings) == 2

      assert Enum.any?(settings, fn setting ->
               setting.key == "key1" && setting.value == "value1"
             end)

      assert Enum.any?(settings, fn setting ->
               setting.key == "key2" && setting.value == "value2"
             end)
    end

    test "returns empty settings when organization has no settings", %{
      grpc_channel: channel,
      organization: organization
    } do
      request = Organization.FetchOrganizationSettingsRequest.new(org_id: organization.id)

      {:ok, response} =
        channel
        |> Stub.fetch_organization_settings(request)

      assert %Organization.FetchOrganizationSettingsResponse{
               settings: settings
             } = response

      assert settings == []
    end

    test "returns an error if the organization is not found", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()
      request = Organization.FetchOrganizationSettingsRequest.new(org_id: org_id)

      assert {:error, %GRPC.RPCError{message: message}} =
               Stub.fetch_organization_settings(channel, request)

      assert message =~ "Organization '#{org_id}' not found."
    end
  end

  describe "repository_integrators/2" do
    test "returns only github integrators when no features are enabled", %{
      grpc_channel: channel,
      organization: organization
    } do
      features = fn a, b ->
        require Logger
        Logger.debug("CALLED WITH: #{inspect(a)} #{inspect(b)}")
        {:ok, []}
      end

      FunRegistry.set!(Support.StubbedProvider, :provide_features, features)
      FeatureProvider.list_features(invalidate: true, reload: true, param: organization.id)

      request = %Organization.RepositoryIntegratorsRequest{org_id: organization.id}
      {:ok, response} = channel |> Stub.repository_integrators(request)

      assert response.primary ==
               InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)

      assert response.available == [
               InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)
             ]

      assert response.enabled == response.available
    end

    test "returns bitbucket integrators when bitbucket features are enabled", %{
      grpc_channel: channel,
      organization: organization
    } do
      features =
        {:ok,
         [
           Support.StubbedProvider.feature("bitbucket", [{:quantity, 1}])
         ]}

      FunRegistry.set!(Support.StubbedProvider, :provide_features, features)

      request = %Organization.RepositoryIntegratorsRequest{org_id: organization.id}
      {:ok, response} = channel |> Stub.repository_integrators(request)

      assert response.primary ==
               InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)

      assert Enum.sort(response.available) ==
               Enum.sort([
                 InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP),
                 InternalApi.RepositoryIntegrator.IntegrationType.value(:BITBUCKET)
               ])

      assert response.enabled == response.available
    end

    test "returns bitbucket and gitlab integrators when features are enabled", %{
      grpc_channel: channel,
      organization: organization
    } do
      features =
        {:ok,
         [
           Support.StubbedProvider.feature("bitbucket", [{:quantity, 1}]),
           Support.StubbedProvider.feature("github_oauth_token", [{:quantity, 1}]),
           Support.StubbedProvider.feature("gitlab", [{:quantity, 1}])
         ]}

      FunRegistry.set!(Support.StubbedProvider, :provide_features, features)

      request = %Organization.RepositoryIntegratorsRequest{org_id: organization.id}
      {:ok, response} = channel |> Stub.repository_integrators(request)

      assert response.primary ==
               InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)

      assert Enum.sort(response.available) ==
               Enum.sort([
                 InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP),
                 InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN),
                 InternalApi.RepositoryIntegrator.IntegrationType.value(:BITBUCKET),
                 InternalApi.RepositoryIntegrator.IntegrationType.value(:GITLAB)
               ])

      assert response.enabled == response.available
    end

    test "returns an error if the organization is not found", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()
      request = %Organization.RepositoryIntegratorsRequest{org_id: org_id}

      assert {:error, %GRPC.RPCError{message: message}} =
               Stub.repository_integrators(channel, request)

      assert message =~ "Organization '#{org_id}' not found."
    end
  end

  describe "list" do
    setup do
      Guard.FrontRepo.delete_all(Guard.FrontRepo.Organization)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      org1 =
        Support.Factories.Organization.insert!(
          name: "Alpha Org",
          username: "alpha-org",
          created_at: DateTime.add(now, -2, :day) |> DateTime.truncate(:second)
        )

      org2 =
        Support.Factories.Organization.insert!(
          name: "Beta Org",
          username: "beta-org",
          created_at: DateTime.add(now, -1, :day) |> DateTime.truncate(:second)
        )

      org3 =
        Support.Factories.Organization.insert!(
          name: "Charlie Org",
          username: "charlie-org",
          created_at: now |> DateTime.truncate(:second)
        )

      org4 =
        Support.Factories.Organization.insert!(
          name: "Soft Deleted Org 1",
          username: "deleted-org-1",
          created_at: now |> DateTime.truncate(:second)
        )

      org5 =
        Support.Factories.Organization.insert!(
          name: "Soft Deleted Org 2",
          username: "deleted-org-2",
          created_at: now |> DateTime.truncate(:second)
        )

      {:ok, _} = Guard.Store.Organization.soft_destroy(org4)
      {:ok, _} = Guard.Store.Organization.soft_destroy(org5)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      [orgs: [org1, org2, org3, org4, org5], now: now, channel: channel]
    end

    test "lists organizations with default parameters", %{
      channel: channel,
      orgs: [org1, org2, org3 | _rest]
    } do
      request = Organization.ListRequest.new()

      {:ok, response} = channel |> Stub.list(request)

      assert %Organization.ListResponse{
               status: %InternalApi.ResponseStatus{code: 0},
               organizations: organizations,
               next_page_token: _
             } = response

      assert length(organizations) == 3
      assert Enum.map(organizations, & &1.name) == [org1.name, org2.name, org3.name]
    end

    test "lists soft-deleted organizations with default parameters", %{
      channel: channel,
      orgs: [_org1, _org2, _org3, org4, org5]
    } do
      request = Organization.ListRequest.new(soft_deleted: true)

      {:ok, response} = channel |> Stub.list(request)

      assert %Organization.ListResponse{
               status: %InternalApi.ResponseStatus{code: 0},
               organizations: organizations,
               next_page_token: _
             } = response

      assert length(organizations) == 2
      assert Enum.map(organizations, & &1.name) == [org4.name, org5.name]
    end

    test "lists organizations with pagination", %{
      channel: channel,
      orgs: [org1, org2, org3 | _rest]
    } do
      # First page
      request = Organization.ListRequest.new(page_size: 2)

      {:ok, response} = channel |> Stub.list(request)

      assert %Organization.ListResponse{
               organizations: first_page,
               next_page_token: next_token
             } = response

      assert length(first_page) == 2
      assert Enum.map(first_page, & &1.name) == [org1.name, org2.name]
      assert next_token != ""

      # Second page
      request = Organization.ListRequest.new(page_size: 2, page_token: next_token)

      {:ok, response} = channel |> Stub.list(request)

      assert %Organization.ListResponse{
               organizations: second_page
             } = response

      assert length(second_page) == 1
      assert Enum.map(second_page, & &1.name) == [org3.name]
    end

    test "lists organizations ordered by creation time", %{
      channel: channel,
      orgs: [org1, org2, org3 | _rest]
    } do
      request =
        Organization.ListRequest.new(
          order: Organization.ListRequest.Order.value(:BY_CREATION_TIME_ASC)
        )

      {:ok, response} = channel |> Stub.list(request)

      assert %Organization.ListResponse{organizations: organizations} = response

      assert length(organizations) == 3
      assert Enum.map(organizations, & &1.name) == [org1.name, org2.name, org3.name]
    end

    test "filters organizations by creation time", %{
      channel: channel,
      now: now,
      orgs: [_, org2, org3 | _rest]
    } do
      one_day_ago = DateTime.add(now, -25, :hour)

      request =
        Organization.ListRequest.new(
          created_at_gt: %Google.Protobuf.Timestamp{
            seconds: DateTime.to_unix(one_day_ago),
            nanos: 0
          }
        )

      {:ok, response} = channel |> Stub.list(request)

      assert %Organization.ListResponse{organizations: organizations} = response

      assert length(organizations) == 2
      assert Enum.map(organizations, & &1.name) == [org2.name, org3.name]
    end

    test "handles empty result set", %{channel: channel} do
      Guard.FrontRepo.delete_all(Guard.FrontRepo.Organization)

      request = Organization.ListRequest.new()

      {:ok, response} = channel |> Stub.list(request)

      assert %Organization.ListResponse{
               status: %InternalApi.ResponseStatus{code: 0},
               organizations: organizations
             } = response

      assert organizations == []
    end
  end

  describe "fetch_organization_contacts" do
    test "returns organization contacts", %{grpc_channel: channel, organization: organization} do
      alias InternalApi.Organization.OrganizationContact.ContactType

      contact1 =
        Support.Factories.Organization.insert_contact!(organization.id,
          contact_type: :CONTACT_TYPE_MAIN,
          name: "John Doe",
          email: "ajohn@example.com",
          phone: "+1234567890"
        )

      contact2 =
        Support.Factories.Organization.insert_contact!(organization.id,
          contact_type: :CONTACT_TYPE_FINANCES,
          name: "Jane Smith",
          email: "bjane@example.com",
          phone: "+1234567890"
        )

      request = Organization.FetchOrganizationContactsRequest.new(org_id: organization.id)

      {:ok, response} =
        channel
        |> Stub.fetch_organization_contacts(request)

      assert length(response.org_contacts) == 2

      [resp_contact1, resp_contact2] = Enum.sort_by(response.org_contacts, & &1.email)

      assert resp_contact1.org_id == contact1.organization_id
      assert resp_contact1.type == ContactType.value(:CONTACT_TYPE_MAIN)
      assert resp_contact1.name == contact1.name
      assert resp_contact1.email == contact1.email
      assert resp_contact1.phone == contact1.phone

      assert resp_contact2.org_id == contact2.organization_id
      assert resp_contact2.type == ContactType.value(:CONTACT_TYPE_FINANCES)
      assert resp_contact2.name == contact2.name
      assert resp_contact2.email == contact2.email
      assert resp_contact2.phone == contact2.phone
    end

    test "handles non-existent organization", %{grpc_channel: channel} do
      non_existent_id = Ecto.UUID.generate()
      request = Organization.FetchOrganizationContactsRequest.new(org_id: non_existent_id)

      assert {:error, %GRPC.RPCError{message: message}} =
               Stub.fetch_organization_contacts(channel, request)

      assert message =~ "Organization '#{non_existent_id}' not found."
    end

    test "handles organization without contacts", %{
      grpc_channel: channel,
      organization: organization
    } do
      request = Organization.FetchOrganizationContactsRequest.new(org_id: organization.id)

      {:ok, response} =
        channel
        |> Stub.fetch_organization_contacts(request)

      assert response.org_contacts == []
    end

    test "handles invalid UUID", %{grpc_channel: channel} do
      request = Organization.FetchOrganizationContactsRequest.new(org_id: "not-a-uuid")

      assert {:error, %GRPC.RPCError{message: message}} =
               Stub.fetch_organization_contacts(channel, request)

      assert message =~ "Invalid organization id or username"
    end
  end

  describe "modify_organization_contact" do
    test "creates a new contact", %{grpc_channel: channel, organization: organization} do
      alias InternalApi.Organization.OrganizationContact.ContactType

      contact = %Organization.OrganizationContact{
        org_id: organization.id,
        type: ContactType.value(:CONTACT_TYPE_MAIN),
        name: "John Doe",
        email: "john@example.com",
        phone: "+1234567890"
      }

      request = Organization.ModifyOrganizationContactRequest.new(org_contact: contact)

      {:ok, response} = Stub.modify_organization_contact(channel, request)

      assert response == %Organization.ModifyOrganizationContactResponse{}

      # Verify contact was created
      stored_contact =
        Guard.FrontRepo.get_by(Guard.FrontRepo.OrganizationContact,
          organization_id: organization.id,
          contact_type: :CONTACT_TYPE_MAIN
        )

      assert stored_contact.name == "John Doe"
      assert stored_contact.email == "john@example.com"
      assert stored_contact.phone == "+1234567890"
    end

    test "updates existing contact", %{grpc_channel: channel, organization: organization} do
      alias InternalApi.Organization.OrganizationContact.ContactType

      Support.Factories.Organization.insert_contact!(organization.id,
        contact_type: :CONTACT_TYPE_MAIN,
        name: "Old Name",
        email: "old@example.com",
        phone: "+0000000000"
      )

      contact = %Organization.OrganizationContact{
        org_id: organization.id,
        type: ContactType.value(:CONTACT_TYPE_MAIN),
        name: "New Name",
        email: "new@example.com",
        phone: "+1234567890"
      }

      request = Organization.ModifyOrganizationContactRequest.new(org_contact: contact)

      {:ok, response} = Stub.modify_organization_contact(channel, request)

      assert response == %Organization.ModifyOrganizationContactResponse{}

      # Verify contact was updated
      stored_contact =
        Guard.FrontRepo.get_by(Guard.FrontRepo.OrganizationContact,
          organization_id: organization.id,
          contact_type: :CONTACT_TYPE_MAIN
        )

      assert stored_contact.name == "New Name"
      assert stored_contact.email == "new@example.com"
      assert stored_contact.phone == "+1234567890"
    end

    test "removes contact when all fields are empty", %{
      grpc_channel: channel,
      organization: organization
    } do
      alias InternalApi.Organization.OrganizationContact.ContactType

      Support.Factories.Organization.insert_contact!(organization.id,
        contact_type: :CONTACT_TYPE_MAIN,
        name: "Old Name",
        email: "old@example.com",
        phone: "+0000000000"
      )

      contact = %Organization.OrganizationContact{
        org_id: organization.id,
        type: ContactType.value(:CONTACT_TYPE_MAIN),
        name: "",
        email: "",
        phone: ""
      }

      request = Organization.ModifyOrganizationContactRequest.new(org_contact: contact)

      {:ok, response} = Stub.modify_organization_contact(channel, request)

      assert response == %Organization.ModifyOrganizationContactResponse{}

      # Verify contact was deleted
      refute Guard.FrontRepo.get_by(Guard.FrontRepo.OrganizationContact,
               organization_id: organization.id,
               contact_type: :CONTACT_TYPE_MAIN
             )
    end

    test "handles non-existent organization", %{grpc_channel: channel} do
      alias InternalApi.Organization.OrganizationContact.ContactType

      non_existent_id = Ecto.UUID.generate()

      contact = %Organization.OrganizationContact{
        org_id: non_existent_id,
        type: ContactType.value(:CONTACT_TYPE_MAIN),
        name: "John Doe",
        email: "john@example.com",
        phone: "+1234567890"
      }

      request = Organization.ModifyOrganizationContactRequest.new(org_contact: contact)

      assert {:error, %GRPC.RPCError{message: message}} =
               Stub.modify_organization_contact(channel, request)

      assert message =~ "Organization '#{non_existent_id}' not found."
    end

    test "handles invalid email format", %{grpc_channel: channel, organization: organization} do
      alias InternalApi.Organization.OrganizationContact.ContactType

      contact = %Organization.OrganizationContact{
        org_id: organization.id,
        type: ContactType.value(:CONTACT_TYPE_MAIN),
        name: "John Doe",
        email: "invalid-email",
        phone: "+1234567890"
      }

      request = Organization.ModifyOrganizationContactRequest.new(org_contact: contact)

      assert {:error, %GRPC.RPCError{message: message}} =
               Stub.modify_organization_contact(channel, request)

      assert message =~ "Invalid contact parameters"
      assert message =~ "email: must have the @ sign and no spaces"
    end
  end

  describe "modify_organization_settings" do
    test "creates new settings", %{grpc_channel: channel, organization: organization} do
      # Verify initial state
      initial_org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert initial_org.settings == nil || initial_org.settings == %{}

      settings = [
        %Organization.OrganizationSetting{key: "theme", value: "dark"},
        %Organization.OrganizationSetting{key: "language", value: "en"}
      ]

      request =
        Organization.ModifyOrganizationSettingsRequest.new(
          org_id: organization.id,
          settings: settings
        )

      {:ok, response} = Stub.modify_organization_settings(channel, request)

      assert %Organization.ModifyOrganizationSettingsResponse{settings: response_settings} =
               response

      assert length(response_settings) == 2
      assert Enum.any?(response_settings, fn s -> s.key == "theme" && s.value == "dark" end)
      assert Enum.any?(response_settings, fn s -> s.key == "language" && s.value == "en" end)

      # Verify settings were saved
      updated_org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert updated_org.settings["theme"] == "dark"
      assert updated_org.settings["language"] == "en"
    end

    test "updates existing settings", %{grpc_channel: channel, organization: organization} do
      # Verify initial state
      initial_org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert initial_org.settings == nil || initial_org.settings == %{}

      # First create some settings
      {:ok, org} =
        Guard.Store.Organization.modify_settings(organization, %{
          "theme" => "light",
          "language" => "en"
        })

      # Verify settings were created
      assert org.settings["theme"] == "light"
      assert org.settings["language"] == "en"

      # Now update them
      settings = [
        %Organization.OrganizationSetting{key: "theme", value: "dark"},
        %Organization.OrganizationSetting{key: "notifications", value: "all"}
      ]

      request =
        Organization.ModifyOrganizationSettingsRequest.new(
          org_id: organization.id,
          settings: settings
        )

      {:ok, response} = Stub.modify_organization_settings(channel, request)

      assert %Organization.ModifyOrganizationSettingsResponse{settings: response_settings} =
               response

      assert length(response_settings) == 3
      assert Enum.any?(response_settings, fn s -> s.key == "theme" && s.value == "dark" end)
      assert Enum.any?(response_settings, fn s -> s.key == "language" && s.value == "en" end)

      assert Enum.any?(response_settings, fn s -> s.key == "notifications" && s.value == "all" end)

      # Verify settings were updated
      updated_org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert updated_org.settings["theme"] == "dark"
      assert updated_org.settings["language"] == "en"
      assert updated_org.settings["notifications"] == "all"
    end

    test "removes settings with empty values", %{
      grpc_channel: channel,
      organization: organization
    } do
      # Verify initial state
      initial_org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert initial_org.settings == nil || initial_org.settings == %{}

      # First create some settings
      {:ok, org} =
        Guard.Store.Organization.modify_settings(organization, %{
          "theme" => "light",
          "language" => "en"
        })

      # Verify settings were created
      assert org.settings["theme"] == "light"
      assert org.settings["language"] == "en"

      # Now remove theme by setting empty value
      settings = [
        %Organization.OrganizationSetting{key: "theme", value: ""},
        %Organization.OrganizationSetting{key: "notifications", value: "all"}
      ]

      request =
        Organization.ModifyOrganizationSettingsRequest.new(
          org_id: organization.id,
          settings: settings
        )

      {:ok, response} = Stub.modify_organization_settings(channel, request)

      assert %Organization.ModifyOrganizationSettingsResponse{settings: response_settings} =
               response

      assert length(response_settings) == 2
      assert Enum.any?(response_settings, fn s -> s.key == "language" && s.value == "en" end)

      assert Enum.any?(response_settings, fn s -> s.key == "notifications" && s.value == "all" end)

      # Verify settings were updated
      updated_org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      refute Map.has_key?(updated_org.settings, "theme")
      assert updated_org.settings["language"] == "en"
      assert updated_org.settings["notifications"] == "all"
    end

    test "handles non-existent organization", %{grpc_channel: channel} do
      non_existent_id = Ecto.UUID.generate()

      settings = [
        %Organization.OrganizationSetting{key: "theme", value: "dark"}
      ]

      request =
        Organization.ModifyOrganizationSettingsRequest.new(
          org_id: non_existent_id,
          settings: settings
        )

      assert {:error, %GRPC.RPCError{message: message}} =
               Stub.modify_organization_settings(channel, request)

      assert message =~ "Organization '#{non_existent_id}' not found."
    end
  end

  describe "list_suspensions" do
    test "lists active suspensions", %{grpc_channel: channel, organization: organization} do
      # Create a few suspensions
      _suspension1 = Support.Factories.Organization.insert_suspension!(organization.id)

      _deleted_suspension =
        Support.Factories.Organization.insert_suspension!(organization.id,
          reason: :ACCOUNT_AT_RISK,
          origin: "security",
          description: "Suspicious activity detected",
          deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      _suspension2 =
        Support.Factories.Organization.insert_suspension!(organization.id,
          reason: :VIOLATION_OF_TOS,
          origin: "compliance",
          description: "Terms of service violation"
        )

      request = Organization.ListSuspensionsRequest.new(org_id: organization.id)
      {:ok, response} = Stub.list_suspensions(channel, request)

      assert %Organization.ListSuspensionsResponse{
               status: %Google.Rpc.Status{code: 0, message: ""},
               suspensions: suspensions
             } = response

      # Should only return active (non-deleted) suspensions
      assert length(suspensions) == 2

      # Verify first suspension
      suspension =
        Enum.find(
          suspensions,
          &(&1.reason == Organization.Suspension.Reason.value(:INSUFFICIENT_FUNDS))
        )

      assert suspension.origin == "billing"
      assert suspension.description == "Account has insufficient funds"
      assert suspension.created_at != nil

      # Verify second suspension
      suspension =
        Enum.find(
          suspensions,
          &(&1.reason == Organization.Suspension.Reason.value(:VIOLATION_OF_TOS))
        )

      assert suspension.origin == "compliance"
      assert suspension.description == "Terms of service violation"
      assert suspension.created_at != nil
    end

    test "returns empty list when no suspensions exist", %{
      grpc_channel: channel,
      organization: organization
    } do
      request = Organization.ListSuspensionsRequest.new(org_id: organization.id)
      {:ok, response} = Stub.list_suspensions(channel, request)

      assert %Organization.ListSuspensionsResponse{
               status: %Google.Rpc.Status{code: 0, message: ""},
               suspensions: []
             } = response
    end

    test "handles non-existent organization", %{grpc_channel: channel} do
      non_existent_id = Ecto.UUID.generate()
      request = Organization.ListSuspensionsRequest.new(org_id: non_existent_id)

      assert {:error, %GRPC.RPCError{message: message}} = Stub.list_suspensions(channel, request)
      assert message =~ "Organization '#{non_existent_id}' not found."
    end
  end

  describe "suspend" do
    test "creates a suspension for organization", %{
      grpc_channel: channel,
      organization: organization
    } do
      request =
        Organization.SuspendRequest.new(
          org_id: organization.id,
          reason: InternalApi.Organization.Suspension.Reason.value(:INSUFFICIENT_FUNDS),
          origin: "billing",
          description: "Account has insufficient funds"
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.suspend(request)
      assert response.status.code == 0

      # Verify suspension was created
      {:ok, list_response} =
        channel
        |> Organization.OrganizationService.Stub.list_suspensions(
          Organization.ListSuspensionsRequest.new(org_id: organization.id)
        )

      assert length(list_response.suspensions) == 1
      [suspension] = list_response.suspensions

      assert suspension.reason ==
               InternalApi.Organization.Suspension.Reason.value(:INSUFFICIENT_FUNDS)

      assert suspension.origin == "billing"
      assert suspension.description == "Account has insufficient funds"
    end

    test "returns error for non-existent organization", %{grpc_channel: channel} do
      non_existent_id = Ecto.UUID.generate()

      request =
        Organization.SuspendRequest.new(
          org_id: non_existent_id,
          reason: InternalApi.Organization.Suspension.Reason.value(:INSUFFICIENT_FUNDS),
          origin: "billing",
          description: "Account has insufficient funds"
        )

      assert {:error, %GRPC.RPCError{message: message}} = Stub.suspend(channel, request)
      assert message =~ "Organization '#{non_existent_id}' not found."
    end
  end

  describe "unsuspend" do
    test "removes suspension and emits events", %{
      grpc_channel: channel,
      organization: organization
    } do
      {:ok, suspension} =
        Guard.Store.Organization.add_suspension(organization, %{
          reason: :INSUFFICIENT_FUNDS,
          origin: "billing",
          description: "Account has insufficient funds"
        })

      request =
        Organization.UnsuspendRequest.new(
          org_id: organization.id,
          reason: InternalApi.Organization.Suspension.Reason.value(suspension.reason)
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.unsuspend(request)
      assert response.status.code == 0

      # Verify suspension was removed
      organization = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      refute organization.suspended
    end

    test "keeps organization suspended when other active suspensions exist", %{
      grpc_channel: channel,
      organization: organization
    } do
      {:ok, suspension1} =
        Guard.Store.Organization.add_suspension(organization, %{
          reason: :INSUFFICIENT_FUNDS,
          origin: "billing"
        })

      {:ok, _} =
        Guard.Store.Organization.add_suspension(organization, %{
          reason: :VIOLATION_OF_TOS,
          origin: "billing"
        })

      request =
        Organization.UnsuspendRequest.new(
          org_id: organization.id,
          reason: InternalApi.Organization.Suspension.Reason.value(suspension1.reason)
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.unsuspend(request)
      assert response.status.code == 0

      # Verify organization is still suspended due to other active suspension
      organization = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert organization.suspended
    end

    test "marks organization as verified when removing VIOLATION_OF_TOS suspension", %{
      grpc_channel: channel,
      organization: organization
    } do
      refute organization.verified

      suspension =
        Support.Factories.Organization.insert_suspension!(organization.id,
          reason: :VIOLATION_OF_TOS
        )

      request =
        Organization.UnsuspendRequest.new(
          org_id: organization.id,
          reason: InternalApi.Organization.Suspension.Reason.value(suspension.reason)
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.unsuspend(request)
      assert response.status.code == 0

      # Verify organization is verified
      organization = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert organization.verified
    end

    test "returns error for non-existent organization", %{grpc_channel: channel} do
      non_existent_id = Ecto.UUID.generate()

      request =
        Organization.UnsuspendRequest.new(
          org_id: non_existent_id,
          reason: InternalApi.Organization.Suspension.Reason.value(:INSUFFICIENT_FUNDS)
        )

      assert {:error, %GRPC.RPCError{message: message}} = Stub.unsuspend(channel, request)
      assert message =~ "Organization '#{non_existent_id}' not found."
    end

    test "returns ok when no active suspension exists", %{
      grpc_channel: channel,
      organization: organization
    } do
      request =
        Organization.UnsuspendRequest.new(
          org_id: organization.id,
          reason: InternalApi.Organization.Suspension.Reason.value(:INSUFFICIENT_FUNDS)
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.unsuspend(request)
      assert response.status.code == 0
    end

    test "returns ok when suspension was already removed", %{
      grpc_channel: channel,
      organization: organization
    } do
      suspension =
        Support.Factories.Organization.insert_suspension!(
          organization.id,
          reason: :INSUFFICIENT_FUNDS,
          deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      request =
        Organization.UnsuspendRequest.new(
          org_id: organization.id,
          reason: InternalApi.Organization.Suspension.Reason.value(suspension.reason)
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.unsuspend(request)
      assert response.status.code == 0
    end
  end

  describe "verify/2" do
    test "verifies organization", %{
      grpc_channel: channel,
      organization: organization
    } do
      refute organization.verified

      request = Organization.VerifyRequest.new(org_id: organization.id)

      {:ok, response} = channel |> Organization.OrganizationService.Stub.verify(request)

      assert response.verified == true
      assert response.org_id == organization.id

      # Verify organization was updated in database
      org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert org.verified == true
    end

    test "returns error when organization doesn't exist", %{grpc_channel: channel} do
      non_existent_id = Ecto.UUID.generate()

      request = Organization.VerifyRequest.new(org_id: non_existent_id)

      assert {:error, %GRPC.RPCError{message: message}} = Stub.verify(channel, request)
      assert message =~ "Organization '#{non_existent_id}' not found."
    end
  end

  describe "is_valid" do
    test "returns true for valid organization attributes", %{grpc_channel: channel} do
      request = %Organization.Organization{
        name: "Test Organization",
        org_username: "test-org",
        owner_id: Ecto.UUID.generate(),
        avatar_url: "",
        org_id: "",
        suspended: false,
        restricted: false,
        open_source: false,
        verified: false,
        ip_allow_list: "",
        allowed_id_providers: "",
        deny_member_workflows: false,
        deny_non_member_workflows: false
      }

      {:ok, response} = channel |> Organization.OrganizationService.Stub.is_valid(request)
      assert response.is_valid
      assert response.errors == ""
    end

    test "returns false with errors for invalid organization attributes", %{grpc_channel: channel} do
      request = %Organization.Organization{
        name: "",
        org_username: "invalid username",
        owner_id: "",
        avatar_url: "",
        org_id: "",
        suspended: false,
        restricted: false,
        open_source: false,
        verified: false,
        ip_allow_list: "",
        allowed_id_providers: "",
        deny_member_workflows: false,
        deny_non_member_workflows: false
      }

      {:ok, response} = channel |> Organization.OrganizationService.Stub.is_valid(request)
      refute response.is_valid

      errors = Jason.decode!(response.errors)
      assert errors["name"] == ["Cannot be empty"]
      assert errors["creator_id"] == ["Cannot be empty"]

      assert errors["username"] == [
               "Use min. 3 characters, only lowercase letters a-z, numbers 0-9 and dash, no spaces."
             ]
    end

    test "returns false for restricted username", %{grpc_channel: channel} do
      request = %Organization.Organization{
        name: "Test Organization",
        org_username: "domain1",
        owner_id: Ecto.UUID.generate(),
        avatar_url: "",
        org_id: "",
        suspended: false,
        restricted: false,
        open_source: false,
        verified: false,
        ip_allow_list: "",
        allowed_id_providers: "",
        deny_member_workflows: false,
        deny_non_member_workflows: false
      }

      {:ok, response} = channel |> Organization.OrganizationService.Stub.is_valid(request)
      refute response.is_valid

      errors = Jason.decode!(response.errors)
      assert errors["username"] == ["Already taken"]
    end

    test "returns false for existing username", %{
      grpc_channel: channel,
      organization: organization
    } do
      request = %Organization.Organization{
        name: "Test Organization",
        org_username: organization.username,
        owner_id: Ecto.UUID.generate(),
        avatar_url: "",
        org_id: "",
        suspended: false,
        restricted: false,
        open_source: false,
        verified: false,
        ip_allow_list: "",
        allowed_id_providers: "",
        deny_member_workflows: false,
        deny_non_member_workflows: false
      }

      {:ok, response} = channel |> Organization.OrganizationService.Stub.is_valid(request)
      refute response.is_valid

      errors = Jason.decode!(response.errors)
      assert errors["username"] == ["Already taken"]
    end

    test "returns false for username longer than 62 characters", %{grpc_channel: channel} do
      request = %Organization.Organization{
        name: "Test Organization",
        org_username: String.duplicate("a", 63),
        owner_id: Ecto.UUID.generate(),
        avatar_url: "",
        org_id: "",
        suspended: false,
        restricted: false,
        open_source: false,
        verified: false,
        ip_allow_list: "",
        allowed_id_providers: "",
        deny_member_workflows: false,
        deny_non_member_workflows: false
      }

      {:ok, response} = channel |> Organization.OrganizationService.Stub.is_valid(request)
      refute response.is_valid

      errors = Jason.decode!(response.errors)
      assert errors["username"] == ["Too long"]
    end
  end

  describe "destroy" do
    test "deletes organization when it exists", %{
      grpc_channel: channel,
      organization: organization
    } do
      with_mocks [{Guard.Events.OrganizationDeleted, [], [publish: fn _, _ -> :ok end]}] do
        request = Organization.DestroyRequest.new(org_id: organization.id)

        {:ok, _} = channel |> Organization.OrganizationService.Stub.destroy(request)

        # Verify organization was soft deleted
        soft_deleted_org = Guard.FrontRepo.get(Guard.FrontRepo.Organization, organization.id)
        assert soft_deleted_org.deleted_at != nil

        half_timestamp = Integer.floor_div(DateTime.utc_now() |> DateTime.to_unix(:second), 1000)
        assert soft_deleted_org.username =~ "#{organization.username}-deleted-#{half_timestamp}"

        assert {:error, {:not_found, _message}} =
                 Guard.Store.Organization.get_by_id(soft_deleted_org.id)

        assert {:error, {:not_found, _message}} =
                 Guard.Store.Organization.get_by_username(soft_deleted_org.username)

        assert_called(
          Guard.Events.OrganizationDeleted.publish(organization.id, type: :soft_delete)
        )
      end
    end

    test "returns error for non-existent organization", %{grpc_channel: channel} do
      with_mocks [{Guard.Events.OrganizationDeleted, [], [publish: fn _, _ -> :ok end]}] do
        non_existent_id = Ecto.UUID.generate()
        request = Organization.DestroyRequest.new(org_id: non_existent_id)

        assert {:error, %GRPC.RPCError{message: message}} = Stub.destroy(channel, request)
        assert message =~ "Organization '#{non_existent_id}' not found."
        assert_not_called(Guard.Events.OrganizationDeleted.publish(:_, type: :soft_delete))
      end
    end
  end

  describe "restore" do
    test "restores an organization", %{grpc_channel: channel, organization: organization} do
      {:ok, organization} = Guard.Store.Organization.soft_destroy(organization)

      with_mocks [{Guard.Events.OrganizationRestored, [], [publish: fn _ -> :ok end]}] do
        request = Organization.RestoreRequest.new(org_id: organization.id)

        {:ok, _} = channel |> Organization.OrganizationService.Stub.restore(request)

        # Verify organization was restored
        restored_org = Guard.FrontRepo.get(Guard.FrontRepo.Organization, organization.id)
        assert restored_org.deleted_at == nil

        assert_called(Guard.Events.OrganizationRestored.publish(organization.id))
      end
    end

    test "if organization is not soft_deleted, returns error", %{
      grpc_channel: channel,
      organization: organization
    } do
      request = Organization.RestoreRequest.new(org_id: organization.id)

      assert {:error, %GRPC.RPCError{message: message, status: status}} =
               Stub.restore(channel, request)

      assert status == GRPC.Status.not_found()
      assert message =~ "Organization '#{organization.id}' not found."
    end
  end

  describe "create/2" do
    test "creates organization with valid params", %{grpc_channel: channel} do
      with_mocks [{Guard.Events.OrganizationCreated, [], [publish: fn _ -> :ok end]}] do
        owner_id = Ecto.UUID.generate()

        request =
          Organization.CreateRequest.new(
            organization_name: "Test Organization",
            organization_username: "test-org-create",
            creator_id: owner_id
          )

        {:ok, response} = channel |> Organization.OrganizationService.Stub.create(request)

        assert response.organization.name == "Test Organization"
        assert response.organization.org_username == "test-org-create"
        assert response.organization.owner_id == owner_id

        # Verify organization was created in database
        org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, response.organization.org_id)
        assert org.name == "Test Organization"
        assert org.username == "test-org-create"
        assert org.creator_id == owner_id

        assert_called(Guard.Events.OrganizationCreated.publish(org.id))
      end
    end

    test "returns error with invalid params", %{grpc_channel: channel} do
      with_mocks [{Guard.Events.OrganizationCreated, [], [publish: fn _ -> :ok end]}] do
        request =
          Organization.CreateRequest.new(
            organization_name: "",
            organization_username: "",
            creator_id: ""
          )

        {:error, response} = channel |> Organization.OrganizationService.Stub.create(request)

        assert response.status == GRPC.Status.invalid_argument()

        assert %{
                 name: ["Cannot be empty"],
                 username: ["Cannot be empty"],
                 creator_id: ["Cannot be empty"]
               }
               |> Jason.encode!() == response.message

        assert_not_called(Guard.Events.OrganizationCreated.publish(:_))
      end
    end

    test "returns error when name is taken", %{grpc_channel: channel} do
      with_mocks [{Guard.Events.OrganizationCreated, [], [publish: fn _ -> :ok end]}] do
        org = Support.Factories.Organization.insert!(username: "test-org")

        request =
          Organization.CreateRequest.new(
            organization_name: "Test Organization",
            organization_username: org.username,
            creator_id: Ecto.UUID.generate()
          )

        {:error, response} = channel |> Organization.OrganizationService.Stub.create(request)

        assert response.status == GRPC.Status.invalid_argument()

        assert %{
                 username: ["Already taken"]
               }
               |> Jason.encode!() == response.message

        assert_not_called(Guard.Events.OrganizationCreated.publish(:_))
      end
    end
  end

  describe "update/2" do
    test "updates organization with valid params", %{
      grpc_channel: channel,
      organization: organization
    } do
      request =
        Organization.UpdateRequest.new(
          organization:
            Organization.Organization.new(
              org_id: organization.id,
              name: "Updated Organization",
              org_username: "updated-org",
              deny_non_member_workflows: true,
              deny_member_workflows: true,
              ip_allow_list: ["192.168.1.1", "192.168.1.2"]
            )
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.update(request)

      assert response.organization.name == "Updated Organization"
      assert response.organization.org_username == "updated-org"
      assert response.organization.deny_non_member_workflows == true
      assert response.organization.deny_member_workflows == true
      assert response.organization.ip_allow_list == ["192.168.1.1", "192.168.1.2"]

      # Verify organization was updated in database
      org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert org.name == "Updated Organization"
      assert org.username == "updated-org"
      assert org.deny_non_member_workflows == true
      assert org.deny_member_workflows == true
      assert org.ip_allow_list == "192.168.1.1,192.168.1.2"
    end

    test "updates allowed_id_providers when non-empty list is provided", %{
      grpc_channel: channel,
      organization: organization
    } do
      assert organization.allowed_id_providers == "api_token,oidc"

      req =
        Organization.UpdateRequest.new(
          organization:
            Organization.Organization.new(
              org_id: organization.id,
              name: organization.name,
              org_username: organization.username,
              allowed_id_providers: ["okta"]
            )
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.update(req)

      assert response.organization.allowed_id_providers == ["okta"]

      updated_org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert updated_org.allowed_id_providers == "okta"
    end

    test "doesn't update allowed_id_providers when empty list is provided", %{
      grpc_channel: channel,
      organization: organization
    } do
      assert organization.allowed_id_providers == "api_token,oidc"

      # Update with empty allowed_id_providers
      request =
        Organization.UpdateRequest.new(
          organization:
            Organization.Organization.new(
              org_id: organization.id,
              name: "Updated Organization",
              org_username: "updated-org"
            )
        )

      {:ok, response} = channel |> Organization.OrganizationService.Stub.update(request)

      assert response.organization.allowed_id_providers == ["api_token", "oidc"]
      updated_org = Guard.FrontRepo.get!(Guard.FrontRepo.Organization, organization.id)
      assert updated_org.allowed_id_providers == "api_token,oidc"
    end

    test "returns error with invalid params", %{
      grpc_channel: channel,
      organization: organization
    } do
      request =
        Organization.UpdateRequest.new(
          organization:
            Organization.Organization.new(
              org_id: organization.id,
              name: "",
              org_username: ""
            )
        )

      {:error, response} = channel |> Organization.OrganizationService.Stub.update(request)

      assert response.status == GRPC.Status.invalid_argument()

      assert %{
               "name" => ["Cannot be empty"],
               "username" => ["Cannot be empty"]
             }
             |> Jason.encode!() == response.message
    end

    test "returns error when username is taken", %{
      grpc_channel: channel,
      organization: organization
    } do
      existing_org = Support.Factories.Organization.insert!(username: "taken-username")

      request =
        Organization.UpdateRequest.new(
          organization:
            Organization.Organization.new(
              org_id: organization.id,
              name: organization.name,
              org_username: existing_org.username
            )
        )

      {:error, response} = channel |> Organization.OrganizationService.Stub.update(request)

      assert response.status == GRPC.Status.invalid_argument()

      assert %{
               "username" => ["Already taken"]
             }
             |> Jason.encode!() == response.message
    end

    test "returns error when organization doesn't exist", %{grpc_channel: channel} do
      non_existent_id = Ecto.UUID.generate()

      request =
        Organization.UpdateRequest.new(
          organization:
            Organization.Organization.new(
              org_id: non_existent_id,
              name: "Updated Organization"
            )
        )

      {:error, response} = channel |> Organization.OrganizationService.Stub.update(request)

      assert response.status == GRPC.Status.not_found()
      assert response.message =~ "Organization '#{non_existent_id}' not found"
    end
  end

  describe "delete_member" do
    test "deletes member by user_id", %{grpc_channel: channel, organization: organization} do
      # Setup user and member
      {:ok, user} = Support.Members.insert_user(name: "John")
      {:ok, member} = Support.Members.insert_member(organization_id: organization.id)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member.github_uid,
          user_id: user.id,
          repo_host: member.repo_host
        )

      request =
        Organization.DeleteMemberRequest.new(
          org_id: organization.id,
          user_id: user.id
        )

      {:ok, _response} = channel |> Stub.delete_member(request)

      assert Guard.FrontRepo.all(Guard.FrontRepo.Member) == []
    end

    test "deletes member by member_id", %{grpc_channel: channel, organization: organization} do
      assert Guard.FrontRepo.all(Guard.FrontRepo.Member) == []
      {:ok, member} = Support.Members.insert_member(organization_id: organization.id)

      request =
        Organization.DeleteMemberRequest.new(
          org_id: organization.id,
          membership_id: member.id
        )

      {:ok, _response} = channel |> Stub.delete_member(request)

      assert Guard.FrontRepo.all(Guard.FrontRepo.Member) == []
    end

    test "returns error when organization doesn't exist", %{grpc_channel: channel} do
      non_existent_org_id = Ecto.UUID.generate()

      request =
        Organization.DeleteMemberRequest.new(
          org_id: non_existent_org_id,
          user_id: Ecto.UUID.generate()
        )

      assert {:error, %GRPC.RPCError{message: message}} = Stub.delete_member(channel, request)
      assert message =~ "Organization '#{non_existent_org_id}' not found."
    end

    test "succeeds when member doesn't exist", %{
      grpc_channel: channel,
      organization: organization
    } do
      request =
        Organization.DeleteMemberRequest.new(
          org_id: organization.id,
          membership_id: Ecto.UUID.generate()
        )

      {:ok, _response} = channel |> Stub.delete_member(request)
    end

    test "succeeds when user doesn't exist", %{grpc_channel: channel, organization: organization} do
      request =
        Organization.DeleteMemberRequest.new(
          org_id: organization.id,
          user_id: Ecto.UUID.generate()
        )

      {:ok, _response} = channel |> Stub.delete_member(request)
    end

    test "deletes only specified user's members", %{
      grpc_channel: channel,
      organization: organization
    } do
      # Setup first user and member
      {:ok, user1} = Support.Members.insert_user(name: "John")
      {:ok, member1} = Support.Members.insert_member(organization_id: organization.id)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "john",
          github_uid: member1.github_uid,
          user_id: user1.id,
          repo_host: member1.repo_host
        )

      # Setup second user and member
      {:ok, user2} = Support.Members.insert_user(name: "Jane")
      {:ok, member2} = Support.Members.insert_member(organization_id: organization.id)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "jane",
          github_uid: member2.github_uid,
          user_id: user2.id,
          repo_host: member2.repo_host
        )

      request =
        Organization.DeleteMemberRequest.new(
          org_id: organization.id,
          user_id: user1.id
        )

      {:ok, _response} = channel |> Stub.delete_member(request)

      members = Guard.FrontRepo.all(Guard.FrontRepo.Member)
      assert length(members) == 1
      [remaining_member] = members
      assert remaining_member.id == member2.id
    end
  end
end
