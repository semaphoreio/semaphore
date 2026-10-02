defmodule PipelinesAPI.Organizations.List.Test do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.Organizations.List

  alias InternalApi.Organization.{DescribeManyResponse, Organization}
  alias InternalApi.RBAC.ListAccessibleOrgsResponse

  @user_id "6f4b8bf6-3f9b-4a1a-9f36-31f532b7a3a5"
  @other_user_id "11111111-2222-3333-4444-555555555555"
  @org_a "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @org_b "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d"
  # 2018-03-31T10:05:43Z
  @created_seconds 1_522_490_743

  setup_all do
    System.put_env("INTERNAL_API_URL_ORGANIZATION", "127.0.0.1:50052")
    System.put_env("INTERNAL_API_URL_RBAC", "127.0.0.1:50052")
    :ok
  end

  setup do
    # Default happy-path stubs: the user belongs to two orgs.
    GrpcMock.stub(RBACMock, :list_accessible_orgs, fn _req, _ ->
      ListAccessibleOrgsResponse.new(org_ids: [@org_a, @org_b])
    end)

    GrpcMock.stub(OrganizationMock, :describe_many, fn req, _ ->
      DescribeManyResponse.new(organizations: Enum.map(req.org_ids, &org/1))
    end)

    :ok
  end

  defp org(org_id) do
    Organization.new(
      org_id: org_id,
      name: "Org " <> org_id,
      org_username: "org-" <> String.slice(org_id, 0, 4),
      created_at: Google.Protobuf.Timestamp.new(seconds: @created_seconds)
    )
  end

  defp call_list(headers \\ [{"x-semaphore-user-id", @user_id}], path \\ "/organizations") do
    conn = conn(:get, path)

    conn =
      Enum.reduce(headers, conn, fn {key, value}, conn ->
        put_req_header(conn, key, value)
      end)

    List.call(conn, List.init([]))
  end

  describe "GET /organizations — authenticated caller (positive)" do
    test "user header -> 200 with the caller's orgs, each carrying id/name/username/created_at" do
      conn = call_list()

      assert conn.status == 200
      body = Poison.decode!(conn.resp_body)
      assert is_list(body)
      assert length(body) == 2

      first = hd(body)
      assert first["organization_id"] == @org_a
      assert first["name"] == "Org " <> @org_a
      assert first["username"] == "org-" <> String.slice(@org_a, 0, 4)
      # created_at is serialized as an ISO8601 string, not a raw proto struct.
      assert first["created_at"] == "2018-03-31T10:05:43Z"
    end

    test "exactly one org -> 200 with a single-element array" do
      GrpcMock.stub(RBACMock, :list_accessible_orgs, fn _req, _ ->
        ListAccessibleOrgsResponse.new(org_ids: [@org_a])
      end)

      conn = call_list()

      assert conn.status == 200
      assert [%{"organization_id" => @org_a}] = Poison.decode!(conn.resp_body)
    end

    test "zero orgs -> 200 with an empty array, and DescribeMany is never called" do
      test_pid = self()

      GrpcMock.stub(RBACMock, :list_accessible_orgs, fn _req, _ ->
        ListAccessibleOrgsResponse.new(org_ids: [])
      end)

      GrpcMock.stub(OrganizationMock, :describe_many, fn req, _ ->
        send(test_pid, :describe_many_called)
        DescribeManyResponse.new(organizations: Enum.map(req.org_ids, &org/1))
      end)

      conn = call_list()

      assert conn.status == 200
      assert Poison.decode!(conn.resp_body) == []
      # No org ids -> no point hydrating; the client short-circuits.
      refute_receive :describe_many_called, 200
    end
  end

  describe "GET /organizations — user scoping (negative / security)" do
    test "missing x-semaphore-user-id header -> 400, nothing downstream is called" do
      test_pid = self()

      GrpcMock.stub(RBACMock, :list_accessible_orgs, fn _req, _ ->
        send(test_pid, :rbac_called)
        ListAccessibleOrgsResponse.new(org_ids: [@org_a])
      end)

      conn = call_list([])

      assert conn.status == 400
      assert Poison.decode!(conn.resp_body) == "missing authenticated user"
      refute_receive :rbac_called, 200
    end

    test "blank x-semaphore-user-id header -> 400 missing authenticated user" do
      conn = call_list([{"x-semaphore-user-id", ""}])

      assert conn.status == 400
      assert Poison.decode!(conn.resp_body) == "missing authenticated user"
    end

    test "a ?user_id= query param CANNOT list another user's orgs: RBAC is keyed off the header" do
      test_pid = self()

      GrpcMock.stub(RBACMock, :list_accessible_orgs, fn req, _ ->
        send(test_pid, {:rbac_req, req})
        ListAccessibleOrgsResponse.new(org_ids: [@org_a])
      end)

      # The caller tries to spoof another user via the query string; the handler
      # must ignore it and use the authenticated header identity.
      conn =
        call_list(
          [{"x-semaphore-user-id", @user_id}],
          "/organizations?user_id=" <> @other_user_id
        )

      assert conn.status == 200
      assert_receive {:rbac_req, req}, 1_000
      assert req.user_id == @user_id
      refute req.user_id == @other_user_id
    end

    test "a spoofed user_id in the request body is likewise ignored" do
      test_pid = self()

      GrpcMock.stub(RBACMock, :list_accessible_orgs, fn req, _ ->
        send(test_pid, {:rbac_req, req})
        ListAccessibleOrgsResponse.new(org_ids: [])
      end)

      conn =
        conn(:get, "/organizations", %{"user_id" => @other_user_id})
        |> put_req_header("x-semaphore-user-id", @user_id)
        |> List.call(List.init([]))

      assert conn.status == 200
      assert_receive {:rbac_req, req}, 1_000
      assert req.user_id == @user_id
    end
  end
end
