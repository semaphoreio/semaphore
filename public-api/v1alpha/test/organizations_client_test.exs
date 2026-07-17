defmodule PipelinesAPI.OrganizationsClient.Test do
  use ExUnit.Case

  alias PipelinesAPI.OrganizationsClient

  alias InternalApi.Billing.CanSetupOrganizationResponse
  alias InternalApi.Organization.{CreateResponse, IsValidResponse, Organization}

  @owner_id "6f4b8bf6-3f9b-4a1a-9f36-31f532b7a3a5"

  setup_all do
    # The client reads these at call time; point them at the fake gRPC server
    # started by Support.FakeServices (same address the docker-compose env uses).
    System.put_env("INTERNAL_API_URL_ORGANIZATION", "127.0.0.1:50052")
    System.put_env("INTERNAL_API_URL_BILLING", "127.0.0.1:50052")
    :ok
  end

  defp ok_status,
    do: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

  defp bad_status(message),
    do:
      InternalApi.ResponseStatus.new(
        code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
        message: message
      )

  describe "is_valid/3" do
    test "valid organization -> :ok, passing name/username/owner through" do
      test_pid = self()

      GrpcMock.stub(OrganizationMock, :is_valid, fn req, _ ->
        send(test_pid, {:is_valid_request, req})
        IsValidResponse.new(is_valid: true)
      end)

      assert :ok = OrganizationsClient.is_valid("Acme Org", "acme", @owner_id)

      assert_receive {:is_valid_request, req}, 1_000
      assert req.name == "Acme Org"
      assert req.org_username == "acme"
      assert req.owner_id == @owner_id
    end

    test "taken username -> customer-friendly user error" do
      GrpcMock.stub(OrganizationMock, :is_valid, fn _, _ ->
        IsValidResponse.new(is_valid: false, errors: "Already taken: acme")
      end)

      assert {:error, {:user, "Organization name is already taken"}} =
               OrganizationsClient.is_valid("Acme Org", "acme", @owner_id)
    end

    test "other validation failures surface the service's message" do
      GrpcMock.stub(OrganizationMock, :is_valid, fn _, _ ->
        IsValidResponse.new(is_valid: false, errors: "Username is too short")
      end)

      assert {:error, {:user, "Username is too short"}} =
               OrganizationsClient.is_valid("A", "a", @owner_id)
    end
  end

  describe "can_setup_organization/1" do
    test "billing allows -> :ok, passing the owner through" do
      test_pid = self()

      GrpcMock.stub(BillingMock, :can_setup_organization, fn req, _ ->
        send(test_pid, {:billing_request, req})
        CanSetupOrganizationResponse.new(allowed: true)
      end)

      assert :ok = OrganizationsClient.can_setup_organization(@owner_id)

      assert_receive {:billing_request, req}, 1_000
      assert req.owner_id == @owner_id
    end

    test "billing denies with reasons -> user error joining them" do
      GrpcMock.stub(BillingMock, :can_setup_organization, fn _, _ ->
        CanSetupOrganizationResponse.new(
          allowed: false,
          errors: ["Payment method missing", "Trial expired"]
        )
      end)

      assert {:error, {:user, "Payment method missing, Trial expired"}} =
               OrganizationsClient.can_setup_organization(@owner_id)
    end

    test "billing denies without reasons -> fallback user error" do
      GrpcMock.stub(BillingMock, :can_setup_organization, fn _, _ ->
        CanSetupOrganizationResponse.new(allowed: false, errors: [])
      end)

      assert {:error, {:user, "Account check failed"}} =
               OrganizationsClient.can_setup_organization(@owner_id)
    end
  end

  describe "create/3" do
    test "created -> {:ok, org}, passing creator/name/username through" do
      test_pid = self()

      GrpcMock.stub(OrganizationMock, :create, fn req, _ ->
        send(test_pid, {:create_request, req})

        CreateResponse.new(
          status: ok_status(),
          organization:
            Organization.new(
              org_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
              name: "Acme Org",
              org_username: "acme"
            )
        )
      end)

      assert {:ok, org} = OrganizationsClient.create(@owner_id, "Acme Org", "acme")
      assert org.org_id == "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
      assert org.name == "Acme Org"
      assert org.org_username == "acme"

      assert_receive {:create_request, req}, 1_000
      assert req.creator_id == @owner_id
      assert req.organization_name == "Acme Org"
      assert req.organization_username == "acme"
    end

    test "non-OK status -> user error with the customer-friendly mapping" do
      GrpcMock.stub(OrganizationMock, :create, fn _, _ ->
        CreateResponse.new(status: bad_status("Already taken: acme"))
      end)

      assert {:error, {:user, "Organization name is already taken"}} =
               OrganizationsClient.create(@owner_id, "Acme Org", "acme")
    end

    test "invalid-argument RPC errors surface as user errors" do
      GrpcMock.stub(OrganizationMock, :create, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "organization name is invalid"
      end)

      assert {:error, {:user, "organization name is invalid"}} =
               OrganizationsClient.create(@owner_id, "Acme Org", "acme")
    end

    test "other RPC errors are internal errors, not user errors" do
      GrpcMock.stub(OrganizationMock, :create, fn _, _ ->
        raise GRPC.RPCError, status: 13, message: "boom"
      end)

      assert {:error, {:internal, "Internal error"}} =
               OrganizationsClient.create(@owner_id, "Acme Org", "acme")
    end
  end
end
