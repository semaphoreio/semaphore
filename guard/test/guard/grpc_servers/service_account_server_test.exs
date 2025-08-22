defmodule Guard.GrpcServers.ServiceAccountServerTest do
  use Guard.RepoCase, async: false
  require Logger

  import Mock

  alias InternalApi.ServiceAccount
  alias InternalApi.ServiceAccount.ServiceAccountService.Stub
  alias Guard.GrpcServers.ServiceAccountServer

  setup do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, %{grpc_channel: channel}}
  end

  describe "create/2" do
    test "creates service account successfully", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()
      creator_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Api.Organization, [:passthrough], [fetch: fn _ -> %{username: "test-org"} end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           create: fn params ->
             {:ok,
              %{
                service_account: %{
                  id: "sa-id",
                  user_id: "user-id",
                  name: params.name,
                  description: params.description,
                  org_id: params.org_id,
                  creator_id: params.creator_id,
                  created_at: DateTime.utc_now(),
                  updated_at: DateTime.utc_now(),
                  deactivated: false
                },
                api_token: "test-api-token"
              }}
           end
         ]}
      ]) do
        request =
          ServiceAccount.CreateRequest.new(
            org_id: org_id,
            name: "Test Service Account",
            description: "Test Description",
            creator_id: creator_id
          )

        {:ok, response} = channel |> Stub.create(request)

        assert response.service_account.name == "Test Service Account"
        assert response.service_account.description == "Test Description"
        assert response.service_account.org_id == org_id
        assert response.service_account.creator_id == creator_id
        assert response.service_account.deactivated == false
        assert response.api_token == "test-api-token"
      end
    end

    test "validates organization exists", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()
      creator_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Api.Organization, [:passthrough], [fetch: fn _ -> nil end]}
      ]) do
        request =
          ServiceAccount.CreateRequest.new(
            org_id: org_id,
            name: "Test Service Account",
            description: "Test Description",
            creator_id: creator_id
          )

        {:error, %GRPC.RPCError{status: 5, message: message}} = channel |> Stub.create(request)

        assert String.contains?(message, "Organization #{org_id} not found")
      end
    end

    test "validates service account name is not empty", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()
      creator_id = Ecto.UUID.generate()

      with_mock Guard.Utils, [:passthrough], validate_uuid!: fn _ -> :ok end do
        request =
          ServiceAccount.CreateRequest.new(
            org_id: org_id,
            name: "   ",
            description: "Test Description",
            creator_id: creator_id
          )

        {:error, %GRPC.RPCError{status: 3, message: message}} = channel |> Stub.create(request)

        assert String.contains?(message, "Service account name cannot be empty")
      end
    end

    test "validates UUID format for org_id", %{grpc_channel: channel} do
      creator_id = Ecto.UUID.generate()

      request =
        ServiceAccount.CreateRequest.new(
          org_id: "invalid-uuid",
          name: "Test Service Account",
          description: "Test Description",
          creator_id: creator_id
        )

      {:error, %GRPC.RPCError{status: 3}} = channel |> Stub.create(request)
    end

    test "validates UUID format for creator_id", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()

      request =
        ServiceAccount.CreateRequest.new(
          org_id: org_id,
          name: "Test Service Account",
          description: "Test Description",
          creator_id: "invalid-uuid"
        )

      {:error, %GRPC.RPCError{status: 3}} = channel |> Stub.create(request)
    end

    test "handles service account creation failure", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()
      creator_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Api.Organization, [:passthrough], [fetch: fn _ -> %{username: "test-org"} end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           create: fn _ -> {:error, [:validation_error]} end
         ]}
      ]) do
        request =
          ServiceAccount.CreateRequest.new(
            org_id: org_id,
            name: "Test Service Account",
            description: "Test Description",
            creator_id: creator_id
          )

        {:error, %GRPC.RPCError{status: 3, message: message}} = channel |> Stub.create(request)

        assert String.contains?(message, "Failed to create service account")
      end
    end
  end

  describe "list/2" do
    test "lists service accounts successfully", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_by_org: fn _, _, _ ->
             {:ok,
              %{
                service_accounts: [
                  %{
                    id: "sa-1",
                    name: "Service Account 1",
                    description: "Description 1",
                    org_id: org_id,
                    creator_id: "creator-1",
                    created_at: DateTime.utc_now(),
                    updated_at: DateTime.utc_now(),
                    deactivated: false
                  },
                  %{
                    id: "sa-2",
                    name: "Service Account 2",
                    description: "Description 2",
                    org_id: org_id,
                    creator_id: "creator-2",
                    created_at: DateTime.utc_now(),
                    updated_at: DateTime.utc_now(),
                    deactivated: false
                  }
                ],
                next_page_token: "next-token"
              }}
           end
         ]}
      ]) do
        request =
          ServiceAccount.ListRequest.new(
            org_id: org_id,
            page_size: 10,
            page_token: ""
          )

        {:ok, response} = channel |> Stub.list(request)

        assert length(response.service_accounts) == 2
        assert response.next_page_token == "next-token"

        first_sa = List.first(response.service_accounts)
        assert first_sa.name == "Service Account 1"
        assert first_sa.org_id == org_id
      end
    end

    test "uses default page size when not provided", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_by_org: fn _, page_size, _ ->
             # Default page size
             assert page_size == 20
             {:ok, %{service_accounts: [], next_page_token: nil}}
           end
         ]}
      ]) do
        request =
          ServiceAccount.ListRequest.new(
            org_id: org_id,
            # Invalid, should use default
            page_size: 0,
            page_token: ""
          )

        {:ok, response} = channel |> Stub.list(request)
        assert response.service_accounts == []
      end
    end

    test "limits page size to maximum", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_by_org: fn _, page_size, _ ->
             # Should use default, not 200
             assert page_size == 20
             {:ok, %{service_accounts: [], next_page_token: nil}}
           end
         ]}
      ]) do
        request =
          ServiceAccount.ListRequest.new(
            org_id: org_id,
            # Over limit, should use default
            page_size: 200,
            page_token: ""
          )

        {:ok, _response} = channel |> Stub.list(request)
      end
    end

    test "handles invalid org_id", %{grpc_channel: channel} do
      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_by_org: fn _, _, _ -> {:error, :invalid_org_id} end
         ]}
      ]) do
        request =
          ServiceAccount.ListRequest.new(
            org_id: "invalid-org-id",
            page_size: 10,
            page_token: ""
          )

        {:error, %GRPC.RPCError{status: 3, message: message}} = channel |> Stub.list(request)

        assert String.contains?(message, "Invalid organization ID")
      end
    end

    test "handles internal errors", %{grpc_channel: channel} do
      org_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_by_org: fn _, _, _ -> {:error, :database_error} end
         ]}
      ]) do
        request =
          ServiceAccount.ListRequest.new(
            org_id: org_id,
            page_size: 10,
            page_token: ""
          )

        {:error, %GRPC.RPCError{status: 13, message: message}} = channel |> Stub.list(request)

        assert String.contains?(message, "Failed to list service accounts")
      end
    end
  end

  describe "describe/2" do
    test "describes service account successfully", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find: fn _ ->
             {:ok,
              %{
                id: service_account_id,
                name: "Test Service Account",
                description: "Test Description",
                org_id: "org-id",
                creator_id: "creator-id",
                created_at: DateTime.utc_now(),
                updated_at: DateTime.utc_now(),
                deactivated: false
              }}
           end
         ]}
      ]) do
        request = ServiceAccount.DescribeRequest.new(service_account_id: service_account_id)

        {:ok, response} = channel |> Stub.describe(request)

        assert response.service_account.id == service_account_id
        assert response.service_account.name == "Test Service Account"
        assert response.service_account.description == "Test Description"
        assert response.service_account.deactivated == false
      end
    end

    test "handles service account not found", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find: fn _ -> {:error, :not_found} end
         ]}
      ]) do
        request = ServiceAccount.DescribeRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 5, message: message}} = channel |> Stub.describe(request)

        assert String.contains?(message, "Service account #{service_account_id} not found")
      end
    end

    test "handles internal errors", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find: fn _ -> {:error, :database_error} end
         ]}
      ]) do
        request = ServiceAccount.DescribeRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 13, message: message}} = channel |> Stub.describe(request)

        assert String.contains?(message, "Failed to describe service account")
      end
    end
  end

  describe "describe_many/2" do
    test "describes multiple service accounts successfully", %{grpc_channel: channel} do
      sa1_id = Ecto.UUID.generate()
      sa2_id = Ecto.UUID.generate()
      sa3_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_many: fn ids ->
             assert length(ids) == 3
             assert sa1_id in ids
             assert sa2_id in ids
             assert sa3_id in ids

             {:ok,
              [
                %{
                  id: sa1_id,
                  name: "Service Account 1",
                  description: "Description 1",
                  org_id: "org-id-1",
                  creator_id: "creator-1",
                  created_at: DateTime.utc_now(),
                  updated_at: DateTime.utc_now(),
                  deactivated: false
                },
                %{
                  id: sa2_id,
                  name: "Service Account 2",
                  description: "Description 2",
                  org_id: "org-id-2",
                  creator_id: "creator-2",
                  created_at: DateTime.utc_now(),
                  updated_at: DateTime.utc_now(),
                  deactivated: true
                },
                %{
                  id: sa3_id,
                  name: "Service Account 3",
                  description: nil,
                  org_id: "org-id-3",
                  creator_id: nil,
                  created_at: DateTime.utc_now(),
                  updated_at: DateTime.utc_now(),
                  deactivated: false
                }
              ]}
           end
         ]}
      ]) do
        request = ServiceAccount.DescribeManyRequest.new(sa_ids: [sa1_id, sa2_id, sa3_id])

        {:ok, response} = channel |> Stub.describe_many(request)

        assert length(response.service_accounts) == 3

        # Verify first service account
        sa1 = Enum.find(response.service_accounts, &(&1.id == sa1_id))
        assert sa1.name == "Service Account 1"
        assert sa1.description == "Description 1"
        assert sa1.org_id == "org-id-1"
        assert sa1.creator_id == "creator-1"
        assert sa1.deactivated == false

        # Verify second service account (deactivated)
        sa2 = Enum.find(response.service_accounts, &(&1.id == sa2_id))
        assert sa2.name == "Service Account 2"
        assert sa2.deactivated == true

        # Verify third service account (nil handling)
        sa3 = Enum.find(response.service_accounts, &(&1.id == sa3_id))
        assert sa3.name == "Service Account 3"
        assert sa3.description == ""
        assert sa3.creator_id == ""
        assert sa3.deactivated == false
      end
    end

    test "returns empty list when no service accounts found", %{grpc_channel: channel} do
      sa1_id = Ecto.UUID.generate()
      sa2_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_many: fn ids ->
             assert length(ids) == 2
             {:ok, []}
           end
         ]}
      ]) do
        request = ServiceAccount.DescribeManyRequest.new(sa_ids: [sa1_id, sa2_id])

        {:ok, response} = channel |> Stub.describe_many(request)

        assert response.service_accounts == []
      end
    end

    test "handles partial matches correctly", %{grpc_channel: channel} do
      existing_id = Ecto.UUID.generate()
      non_existent_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_many: fn ids ->
             assert length(ids) == 2
             assert existing_id in ids
             assert non_existent_id in ids

             # Return only the existing one
             {:ok,
              [
                %{
                  id: existing_id,
                  name: "Existing SA",
                  description: "Exists",
                  org_id: "org-id",
                  creator_id: "creator-id",
                  created_at: DateTime.utc_now(),
                  updated_at: DateTime.utc_now(),
                  deactivated: false
                }
              ]}
           end
         ]}
      ]) do
        request = ServiceAccount.DescribeManyRequest.new(sa_ids: [existing_id, non_existent_id])

        {:ok, response} = channel |> Stub.describe_many(request)

        assert length(response.service_accounts) == 1
        assert hd(response.service_accounts).id == existing_id
      end
    end

    test "handles empty input list", %{grpc_channel: channel} do
      with_mocks([
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_many: fn ids ->
             assert ids == []
             {:ok, []}
           end
         ]}
      ]) do
        request = ServiceAccount.DescribeManyRequest.new(sa_ids: [])

        {:ok, response} = channel |> Stub.describe_many(request)

        assert response.service_accounts == []
      end
    end

    test "validates UUID format for all IDs", %{grpc_channel: channel} do
      valid_id = Ecto.UUID.generate()

      request = ServiceAccount.DescribeManyRequest.new(sa_ids: [valid_id, "invalid-uuid"])

      {:error, %GRPC.RPCError{status: 3}} = channel |> Stub.describe_many(request)
    end

    test "handles internal errors", %{grpc_channel: channel} do
      sa_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_many: fn _ -> {:error, :database_error} end
         ]}
      ]) do
        request = ServiceAccount.DescribeManyRequest.new(sa_ids: [sa_id])

        {:error, %GRPC.RPCError{status: 13, message: message}} =
          channel |> Stub.describe_many(request)

        assert String.contains?(message, "Failed to describe service accounts")
      end
    end

    test "handles large number of IDs", %{grpc_channel: channel} do
      # Generate 50 IDs to test batch processing
      ids = for _ <- 1..50, do: Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.Store.ServiceAccount, [:passthrough],
         [
           find_many: fn received_ids ->
             assert length(received_ids) == 50
             # Return only the first 10 to simulate partial results
             service_accounts =
               received_ids
               |> Enum.take(10)
               |> Enum.map(fn id ->
                 %{
                   id: id,
                   name: "SA #{id}",
                   description: "Description",
                   org_id: "org-id",
                   creator_id: "creator-id",
                   created_at: DateTime.utc_now(),
                   updated_at: DateTime.utc_now(),
                   deactivated: false
                 }
               end)

             {:ok, service_accounts}
           end
         ]}
      ]) do
        request = ServiceAccount.DescribeManyRequest.new(sa_ids: ids)

        {:ok, response} = channel |> Stub.describe_many(request)

        assert length(response.service_accounts) == 10
      end
    end
  end

  describe "update/2" do
    test "updates service account successfully", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           update: fn id, params ->
             assert id == service_account_id
             assert params.name == "Updated Name"
             assert params.description == "Updated Description"

             {:ok,
              %{
                id: service_account_id,
                name: "Updated Name",
                description: "Updated Description",
                org_id: "org-id",
                creator_id: "creator-id",
                created_at: DateTime.utc_now(),
                updated_at: DateTime.utc_now(),
                deactivated: false
              }}
           end
         ]}
      ]) do
        request =
          ServiceAccount.UpdateRequest.new(
            service_account_id: service_account_id,
            name: "Updated Name",
            description: "Updated Description"
          )

        {:ok, response} = channel |> Stub.update(request)

        assert response.service_account.name == "Updated Name"
        assert response.service_account.description == "Updated Description"
      end
    end

    test "validates service account name is not empty", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mock Guard.Utils, [:passthrough], validate_uuid!: fn _ -> :ok end do
        request =
          ServiceAccount.UpdateRequest.new(
            service_account_id: service_account_id,
            name: "   ",
            description: "Updated Description"
          )

        {:error, %GRPC.RPCError{status: 3, message: message}} = channel |> Stub.update(request)

        assert String.contains?(message, "Service account name cannot be empty")
      end
    end

    test "handles service account not found", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           update: fn _, _ -> {:error, :not_found} end
         ]}
      ]) do
        request =
          ServiceAccount.UpdateRequest.new(
            service_account_id: service_account_id,
            name: "Updated Name",
            description: "Updated Description"
          )

        {:error, %GRPC.RPCError{status: 5, message: message}} = channel |> Stub.update(request)

        assert String.contains?(message, "Service account #{service_account_id} not found")
      end
    end

    test "handles update failure", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           update: fn _, _ -> {:error, [:validation_error]} end
         ]}
      ]) do
        request =
          ServiceAccount.UpdateRequest.new(
            service_account_id: service_account_id,
            name: "Updated Name",
            description: "Updated Description"
          )

        {:error, %GRPC.RPCError{status: 3, message: message}} = channel |> Stub.update(request)

        assert String.contains?(message, "Failed to update service account")
      end
    end
  end

  describe "deactivate/2" do
    test "deactivates service account successfully", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           deactivate: fn id ->
             assert id == service_account_id
             {:ok, :deactivated}
           end
         ]}
      ]) do
        request = ServiceAccount.DeactivateRequest.new(service_account_id: service_account_id)

        {:ok, _response} = channel |> Stub.deactivate(request)
      end
    end

    test "handles service account not found", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           deactivate: fn _ -> {:error, :not_found} end
         ]}
      ]) do
        request = ServiceAccount.DeactivateRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 5, message: message}} =
          channel |> Stub.deactivate(request)

        assert String.contains?(message, "Service account #{service_account_id} not found")
      end
    end

    test "handles internal errors", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           deactivate: fn _ -> {:error, :database_error} end
         ]}
      ]) do
        request = ServiceAccount.DeactivateRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 13, message: message}} =
          channel |> Stub.deactivate(request)

        assert String.contains?(message, "Failed to deactivate service account")
      end
    end
  end

  describe "reactivate/2" do
    test "reactivates service account successfully", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           reactivate: fn id ->
             assert id == service_account_id
             {:ok, :reactivated}
           end
         ]}
      ]) do
        request = ServiceAccount.ReactivateRequest.new(service_account_id: service_account_id)

        {:ok, _response} = channel |> Stub.reactivate(request)
      end
    end

    test "handles service account not found", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           reactivate: fn _ -> {:error, :not_found} end
         ]}
      ]) do
        request = ServiceAccount.ReactivateRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 5, message: message}} =
          channel |> Stub.reactivate(request)

        assert String.contains?(message, "Service account #{service_account_id} not found")
      end
    end

    test "handles internal errors", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           reactivate: fn _ -> {:error, :database_error} end
         ]}
      ]) do
        request = ServiceAccount.ReactivateRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 13, message: message}} =
          channel |> Stub.reactivate(request)

        assert String.contains?(message, "Failed to reactivate service account")
      end
    end
  end

  describe "destroy/2" do
    test "destroys service account successfully", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           destroy: fn id ->
             assert id == service_account_id
             {:ok, :destroyed}
           end
         ]}
      ]) do
        request = ServiceAccount.DestroyRequest.new(service_account_id: service_account_id)

        {:ok, _response} = channel |> Stub.destroy(request)
      end
    end

    test "handles service account not found", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           destroy: fn _ -> {:error, :not_found} end
         ]}
      ]) do
        request = ServiceAccount.DestroyRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 5, message: message}} = channel |> Stub.destroy(request)

        assert String.contains?(message, "Service account #{service_account_id} not found")
      end
    end

    test "handles internal errors", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           destroy: fn _ -> {:error, :database_error} end
         ]}
      ]) do
        request = ServiceAccount.DestroyRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 13, message: message}} = channel |> Stub.destroy(request)

        assert String.contains?(message, "Failed to destroy service account")
      end
    end
  end

  describe "regenerate_token/2" do
    test "regenerates token successfully", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           regenerate_token: fn id ->
             assert id == service_account_id
             {:ok, "new-api-token"}
           end
         ]}
      ]) do
        request =
          ServiceAccount.RegenerateTokenRequest.new(service_account_id: service_account_id)

        {:ok, response} = channel |> Stub.regenerate_token(request)

        assert response.api_token == "new-api-token"
      end
    end

    test "handles service account not found", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           regenerate_token: fn _ -> {:error, :not_found} end
         ]}
      ]) do
        request =
          ServiceAccount.RegenerateTokenRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 5, message: message}} =
          channel |> Stub.regenerate_token(request)

        assert String.contains?(message, "Service account #{service_account_id} not found")
      end
    end

    test "handles internal errors", %{grpc_channel: channel} do
      service_account_id = Ecto.UUID.generate()

      with_mocks([
        {Guard.Utils, [:passthrough], [validate_uuid!: fn _ -> :ok end]},
        {Guard.ServiceAccount.Actions, [:passthrough],
         [
           regenerate_token: fn _ -> {:error, :token_generation_error} end
         ]}
      ]) do
        request =
          ServiceAccount.RegenerateTokenRequest.new(service_account_id: service_account_id)

        {:error, %GRPC.RPCError{status: 13, message: message}} =
          channel |> Stub.regenerate_token(request)

        assert String.contains?(message, "Failed to regenerate token")
      end
    end
  end

  describe "helper functions" do
    test "map_service_account/1 converts service account to protobuf format" do
      service_account = %{
        id: "sa-id",
        name: "Test SA",
        description: "Test Description",
        org_id: "org-id",
        creator_id: "creator-id",
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        deactivated: false
      }

      # Test the private function through the public interface
      result = ServiceAccountServer.map_service_account(service_account)

      assert result.id == "sa-id"
      assert result.name == "Test SA"
      assert result.description == "Test Description"
      assert result.org_id == "org-id"
      assert result.creator_id == "creator-id"
      assert result.deactivated == false
      assert result.created_at != nil
      assert result.updated_at != nil
    end

    test "map_service_account/1 handles nil values" do
      service_account = %{
        id: "sa-id",
        name: "Test SA",
        description: nil,
        org_id: "org-id",
        creator_id: nil,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        deactivated: nil
      }

      result = ServiceAccountServer.map_service_account(service_account)

      assert result.description == ""
      assert result.creator_id == ""
      assert result.deactivated == false
    end
  end
end
