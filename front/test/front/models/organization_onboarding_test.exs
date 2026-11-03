defmodule Front.Models.OrganizationOnboardingTest do
  use ExUnit.Case, async: false

  alias Front.Models.OrganizationOnboarding
  alias InternalApi.Billing.CanSetupOrganizationResponse
  alias InternalApi.Organization.{CreateResponse, IsValidResponse, Organization}

  @user_id "00000000-0000-4000-8000-000000000001"

  setup do
    # The billing check only runs on SaaS.
    edition = Application.get_env(:front, :edition)
    Application.put_env(:front, :edition, "")
    on_exit(fn -> Application.put_env(:front, :edition, edition) end)

    test_pid = self()

    GrpcMock.stub(OrganizationMock, :is_valid, fn _req, _ ->
      IsValidResponse.new(is_valid: true)
    end)

    GrpcMock.stub(OrganizationMock, :create, fn req, _ ->
      send(test_pid, {:create, req})

      CreateResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization:
          Organization.new(org_id: Ecto.UUID.generate(), org_username: req.organization_username)
      )
    end)

    :ok
  end

  defp stub_billing(response) do
    test_pid = self()

    GrpcMock.stub(BillingMock, :can_setup_organization, fn req, _ ->
      send(test_pid, {:can_setup, req})
      response
    end)
  end

  describe "create_organization/1" do
    test "sends reserve: true when checking billing before creating" do
      stub_billing(CanSetupOrganizationResponse.new(allowed: true, errors: []))

      assert {:ok, model} =
               %{"url" => "new-org", "user_id" => @user_id}
               |> OrganizationOnboarding.new()
               |> OrganizationOnboarding.create_organization()

      assert model.id
      assert_receive {:can_setup, req}
      assert req.owner_id == @user_id
      assert req.reserve == true
      assert_receive {:create, %{creator_id: @user_id}}
    end

    test "does not create the organization when billing refuses" do
      stub_billing(CanSetupOrganizationResponse.new(allowed: false, errors: ["limit reached"]))

      assert {:error, "limit reached"} =
               %{"url" => "new-org", "user_id" => @user_id}
               |> OrganizationOnboarding.new()
               |> OrganizationOnboarding.create_organization()

      assert_receive {:can_setup, %{reserve: true}}
      refute_receive {:create, _}
    end
  end

  describe "FrontWeb.BillingView.can_create_organization?/1" do
    test "does not set reserve" do
      stub_billing(CanSetupOrganizationResponse.new(allowed: true, errors: []))

      conn = %Plug.Conn{assigns: %{user_id: @user_id}}
      assert FrontWeb.BillingView.can_create_organization?(conn)

      assert_receive {:can_setup, req}
      assert req.owner_id == @user_id
      refute req.reserve
    end
  end
end
