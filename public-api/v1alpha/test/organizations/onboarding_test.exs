defmodule PipelinesAPI.Organizations.Onboarding.Test do
  use ExUnit.Case

  alias PipelinesAPI.Organizations.Onboarding

  alias InternalApi.Billing.CanSetupOrganizationResponse
  alias InternalApi.Organization.{CreateResponse, IsValidResponse, Organization}

  @owner_id "6f4b8bf6-3f9b-4a1a-9f36-31f532b7a3a5"

  setup_all do
    System.put_env("INTERNAL_API_URL_ORGANIZATION", "127.0.0.1:50052")
    System.put_env("INTERNAL_API_URL_BILLING", "127.0.0.1:50052")
    :ok
  end

  setup do
    on_prem? = Application.fetch_env!(:pipelines_api, :on_prem?)
    on_exit(fn -> Application.put_env(:pipelines_api, :on_prem?, on_prem?) end)

    test_pid = self()

    # Innocuous defaults; individual tests re-stub what they exercise. Billing
    # and create both announce being called so tests can assert they were NOT.
    GrpcMock.stub(OrganizationMock, :is_valid, fn _, _ ->
      IsValidResponse.new(is_valid: true)
    end)

    GrpcMock.stub(BillingMock, :can_setup_organization, fn _, _ ->
      send(test_pid, :billing_called)
      CanSetupOrganizationResponse.new(allowed: true)
    end)

    GrpcMock.stub(OrganizationMock, :create, fn _, _ ->
      send(test_pid, :create_called)

      CreateResponse.new(
        status:
          InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization:
          Organization.new(
            org_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
            name: "Acme Org",
            org_username: "acme"
          )
      )
    end)

    :ok
  end

  describe "create_organization/3 on SaaS (billing gate active)" do
    setup do
      Application.put_env(:pipelines_api, :on_prem?, false)
      :ok
    end

    test "valid + billing allowed -> creates the organization" do
      assert {:ok, org} = Onboarding.create_organization("Acme Org", "acme", @owner_id)
      assert org.org_username == "acme"

      assert_receive :billing_called, 1_000
      assert_receive :create_called, 1_000
    end

    test "billing denied -> user error and the org is never created" do
      GrpcMock.stub(BillingMock, :can_setup_organization, fn _, _ ->
        CanSetupOrganizationResponse.new(allowed: false, errors: ["Payment method missing"])
      end)

      assert {:error, {:user, "Payment method missing"}} =
               Onboarding.create_organization("Acme Org", "acme", @owner_id)

      refute_receive :create_called, 200
    end

    test "invalid name/username -> user error before billing or creation" do
      GrpcMock.stub(OrganizationMock, :is_valid, fn _, _ ->
        IsValidResponse.new(is_valid: false, errors: "Username is too short")
      end)

      assert {:error, {:user, "Username is too short"}} =
               Onboarding.create_organization("A", "a", @owner_id)

      refute_receive :billing_called, 200
      refute_receive :create_called, 200
    end
  end

  describe "create_organization/3 on-prem (no billing service exists)" do
    setup do
      Application.put_env(:pipelines_api, :on_prem?, true)
      :ok
    end

    test "skips the billing gate entirely and creates the organization" do
      # Even a denying billing service must not matter — it is never called.
      test_pid = self()

      GrpcMock.stub(BillingMock, :can_setup_organization, fn _, _ ->
        send(test_pid, :billing_called)
        CanSetupOrganizationResponse.new(allowed: false, errors: ["should not be consulted"])
      end)

      assert {:ok, org} = Onboarding.create_organization("Acme Org", "acme", @owner_id)
      assert org.org_username == "acme"

      refute_receive :billing_called, 200
      assert_receive :create_called, 1_000
    end

    test "validation still applies on-prem" do
      GrpcMock.stub(OrganizationMock, :is_valid, fn _, _ ->
        IsValidResponse.new(is_valid: false, errors: "Already taken: acme")
      end)

      assert {:error, {:user, "Organization name is already taken"}} =
               Onboarding.create_organization("Acme Org", "acme", @owner_id)

      refute_receive :create_called, 200
    end
  end
end
