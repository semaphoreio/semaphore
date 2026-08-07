defmodule PipelinesAPI.Organizations.Create.Test do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.Organizations.Create

  alias InternalApi.Billing.CanSetupOrganizationResponse
  alias InternalApi.Organization.{CreateResponse, IsValidResponse, Organization}

  @user_id "6f4b8bf6-3f9b-4a1a-9f36-31f532b7a3a5"
  @org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"

  setup_all do
    System.put_env("INTERNAL_API_URL_ORGANIZATION", "127.0.0.1:50052")
    System.put_env("INTERNAL_API_URL_BILLING", "127.0.0.1:50052")
    :ok
  end

  setup do
    on_prem? = Application.fetch_env!(:pipelines_api, :on_prem?)
    Application.put_env(:pipelines_api, :on_prem?, false)
    on_exit(fn -> Application.put_env(:pipelines_api, :on_prem?, on_prem?) end)

    GrpcMock.stub(OrganizationMock, :is_valid, fn _, _ ->
      IsValidResponse.new(is_valid: true)
    end)

    GrpcMock.stub(BillingMock, :can_setup_organization, fn _, _ ->
      CanSetupOrganizationResponse.new(allowed: true)
    end)

    GrpcMock.stub(OrganizationMock, :create, fn req, _ ->
      CreateResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization:
          Organization.new(
            org_id: @org_id,
            name: req.organization_name,
            org_username: req.organization_username
          )
      )
    end)

    :ok
  end

  defp call_create(params, headers \\ [{"x-semaphore-user-id", @user_id}]) do
    conn = conn(:post, "/organizations", params)

    conn =
      Enum.reduce(headers, conn, fn {key, value}, conn ->
        put_req_header(conn, key, value)
      end)

    Create.call(conn, Create.init([]))
  end

  describe "POST /organizations — authenticated caller" do
    test "username + user header -> 200 with the created org" do
      conn = call_create(%{"username" => "acme", "name" => "Acme Org"})

      assert conn.status == 200

      assert Poison.decode!(conn.resp_body) == %{
               "organization_id" => @org_id,
               "name" => "Acme Org",
               "username" => "acme"
             }
    end

    test "name defaults to username when omitted" do
      conn = call_create(%{"username" => "acme"})

      assert conn.status == 200
      assert %{"name" => "acme", "username" => "acme"} = Poison.decode!(conn.resp_body)
    end

    test "the authenticated user becomes the org creator" do
      test_pid = self()

      GrpcMock.stub(OrganizationMock, :create, fn req, _ ->
        send(test_pid, {:create_request, req})

        CreateResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization: Organization.new(org_id: @org_id, name: req.organization_name)
        )
      end)

      assert call_create(%{"username" => "acme"}).status == 200

      assert_receive {:create_request, req}, 1_000
      assert req.creator_id == @user_id
    end
  end

  describe "POST /organizations — bad requests fail correctly" do
    test "missing username -> 400, nothing downstream is called" do
      test_pid = self()

      GrpcMock.stub(OrganizationMock, :is_valid, fn _, _ ->
        send(test_pid, :is_valid_called)
        IsValidResponse.new(is_valid: true)
      end)

      conn = call_create(%{})

      assert conn.status == 400
      assert conn.halted
      assert Poison.decode!(conn.resp_body) == "username must be present"
      refute_receive :is_valid_called, 200
    end

    test "blank username -> 400" do
      conn = call_create(%{"username" => "   "})

      assert conn.status == 400
      assert Poison.decode!(conn.resp_body) == "username must be present"
    end

    test "missing x-semaphore-user-id header -> 400 missing authenticated user" do
      conn = call_create(%{"username" => "acme"}, [])

      assert conn.status == 400
      assert Poison.decode!(conn.resp_body) == "missing authenticated user"
    end

    test "billing denial -> 400 with the billing reason" do
      GrpcMock.stub(BillingMock, :can_setup_organization, fn _, _ ->
        CanSetupOrganizationResponse.new(allowed: false, errors: ["Payment method missing"])
      end)

      conn = call_create(%{"username" => "acme"})

      assert conn.status == 400
      assert Poison.decode!(conn.resp_body) == "Payment method missing"
    end

    test "taken username -> 400 with the friendly message" do
      GrpcMock.stub(OrganizationMock, :is_valid, fn _, _ ->
        IsValidResponse.new(is_valid: false, errors: "Already taken: acme")
      end)

      conn = call_create(%{"username" => "acme"})

      assert conn.status == 400
      assert Poison.decode!(conn.resp_body) == "Organization name is already taken"
    end
  end
end
