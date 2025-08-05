defmodule FrontWeb.ServiceAccountControllerTest do
  use FrontWeb.ConnCase
  import Mox
  alias Front.Models.ServiceAccount
  alias Support.Stubs.DB

  setup :verify_on_exit!

  setup %{conn: conn} do
    Cacheman.clear(:front)
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user_id = DB.first(:users) |> Map.get(:id)
    org_id = DB.first(:organizations) |> Map.get(:id)

    Support.Stubs.PermissionPatrol.remove_all_permissions()

    # Set up base permissions
    Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
      "organization.view",
      "organization.service_accounts.view"
    ])

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    {:ok, conn: conn, org_id: org_id, user_id: user_id}
  end

  describe "GET /service_accounts" do
    test "lists service accounts successfully", %{conn: conn, org_id: org_id} do
      service_account = %ServiceAccount{
        id: "sa_123",
        name: "Test Service Account",
        description: "Test description",
        created_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z],
        deactivated: false
      }

      expect(ServiceAccountMock, :list, fn ^org_id, 20, nil ->
        {:ok, {[service_account], "next_page_token"}}
      end)

      conn = get(conn, "/service_accounts")

      assert json_response(conn, 200) == %{
               "service_accounts" => [
                 %{
                   "id" => "sa_123",
                   "name" => "Test Service Account",
                   "description" => "Test description",
                   "created_at" => "2024-01-01T10:00:00Z",
                   "updated_at" => "2024-01-01T10:00:00Z",
                   "deactivated" => false
                 }
               ]
             }

      assert get_resp_header(conn, "x-next-page-token") == ["next_page_token"]
    end

    test "handles pagination parameters", %{conn: conn, org_id: org_id} do
      expect(ServiceAccountMock, :list, fn ^org_id, 10, "page_token_123" ->
        {:ok, {[], nil}}
      end)

      conn =
        get(conn, "/service_accounts", %{"page_size" => "10", "page_token" => "page_token_123"})

      assert json_response(conn, 200) == %{"service_accounts" => []}
      assert get_resp_header(conn, "x-next-page-token") == [""]
    end

    test "handles backend errors", %{conn: conn, org_id: org_id} do
      expect(ServiceAccountMock, :list, fn ^org_id, 20, nil ->
        {:error, "Failed to list service accounts"}
      end)

      conn = get(conn, "/service_accounts")

      assert json_response(conn, 422) == %{"error" => "Failed to list service accounts"}
    end

    test "requires service_accounts.view permission", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, ["organization.view"])

      conn = get(conn, "/service_accounts")

      assert html_response(conn, 404) =~ "Page not found"
    end
  end

  describe "POST /service_accounts" do
    setup %{org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.service_accounts.manage"
      ])

      :ok
    end

    test "creates service account successfully", %{conn: conn, org_id: org_id, user_id: user_id} do
      service_account = %ServiceAccount{
        id: "sa_new",
        name: "New Service Account",
        description: "New description",
        created_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z],
        deactivated: false
      }

      expect(ServiceAccountMock, :create, fn ^org_id,
                                             "New Service Account",
                                             "New description",
                                             ^user_id ->
        {:ok, {service_account, "api_token_123"}}
      end)

      conn =
        post(conn, "/service_accounts", %{
          "name" => "New Service Account",
          "description" => "New description"
        })

      assert json_response(conn, 201) == %{
               "id" => "sa_new",
               "name" => "New Service Account",
               "description" => "New description",
               "created_at" => "2024-01-01T10:00:00Z",
               "updated_at" => "2024-01-01T10:00:00Z",
               "deactivated" => false,
               "api_token" => "api_token_123"
             }
    end

    test "handles empty parameters", %{conn: conn, org_id: org_id, user_id: user_id} do
      expect(ServiceAccountMock, :create, fn ^org_id, "", "", ^user_id ->
        {:error, "Name is required"}
      end)

      conn = post(conn, "/service_accounts", %{})

      assert json_response(conn, 422) == %{"error" => "Name is required"}
    end

    test "handles backend errors", %{conn: conn, org_id: org_id, user_id: user_id} do
      expect(ServiceAccountMock, :create, fn ^org_id, "Test", "Desc", ^user_id ->
        {:error, "Failed to create service account"}
      end)

      conn =
        post(conn, "/service_accounts", %{
          "name" => "Test",
          "description" => "Desc"
        })

      assert json_response(conn, 422) == %{"error" => "Failed to create service account"}
    end

    test "requires service_accounts.manage permission", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.view",
        "organization.service_accounts.view"
      ])

      conn = post(conn, "/service_accounts", %{"name" => "Test"})

      assert html_response(conn, 404) =~ "Page not found"
    end
  end

  describe "GET /service_accounts/:id" do
    test "retrieves service account successfully", %{conn: conn} do
      service_account = %ServiceAccount{
        id: "sa_123",
        name: "Test Service Account",
        description: "Test description",
        created_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z],
        deactivated: false
      }

      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:ok, service_account}
      end)

      conn = get(conn, "/service_accounts/sa_123")

      assert json_response(conn, 200) == %{
               "id" => "sa_123",
               "name" => "Test Service Account",
               "description" => "Test description",
               "created_at" => "2024-01-01T10:00:00Z",
               "updated_at" => "2024-01-01T10:00:00Z",
               "deactivated" => false
             }
    end

    test "handles not found", %{conn: conn} do
      expect(ServiceAccountMock, :describe, fn "sa_nonexistent" ->
        {:error, "Service account not found"}
      end)

      conn = get(conn, "/service_accounts/sa_nonexistent")

      assert json_response(conn, 422) == %{"error" => "Service account not found"}
    end
  end

  describe "PUT /service_accounts/:id" do
    setup %{org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.service_accounts.manage"
      ])

      :ok
    end

    test "updates service account successfully", %{conn: conn} do
      updated_account = %ServiceAccount{
        id: "sa_123",
        name: "Updated Name",
        description: "Updated description",
        created_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-02 10:00:00Z],
        deactivated: false
      }

      expect(ServiceAccountMock, :update, fn "sa_123", "Updated Name", "Updated description" ->
        {:ok, updated_account}
      end)

      conn =
        put(conn, "/service_accounts/sa_123", %{
          "name" => "Updated Name",
          "description" => "Updated description"
        })

      assert json_response(conn, 200) == %{
               "id" => "sa_123",
               "name" => "Updated Name",
               "description" => "Updated description",
               "created_at" => "2024-01-01T10:00:00Z",
               "updated_at" => "2024-01-02T10:00:00Z",
               "deactivated" => false
             }
    end

    test "handles update errors", %{conn: conn} do
      expect(ServiceAccountMock, :update, fn "sa_123", "", "" ->
        {:error, "Failed to update"}
      end)

      conn = put(conn, "/service_accounts/sa_123", %{})

      assert json_response(conn, 422) == %{"error" => "Failed to update"}
    end
  end

  describe "DELETE /service_accounts/:id" do
    setup %{org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.service_accounts.manage"
      ])

      :ok
    end

    test "deletes service account successfully", %{conn: conn} do
      service_account = %ServiceAccount{
        id: "sa_123",
        name: "To Delete",
        description: "Will be deleted",
        created_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z],
        deactivated: false
      }

      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:ok, service_account}
      end)

      expect(ServiceAccountMock, :delete, fn "sa_123" ->
        :ok
      end)

      conn = delete(conn, "/service_accounts/sa_123")

      assert response(conn, 204) == ""
    end

    test "handles delete errors", %{conn: conn} do
      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:error, "Not found"}
      end)

      conn = delete(conn, "/service_accounts/sa_123")

      assert json_response(conn, 422) == %{"error" => "Not found"}
    end
  end

  describe "POST /service_accounts/:id/regenerate_token" do
    setup %{org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.service_accounts.manage"
      ])

      :ok
    end

    test "regenerates token successfully", %{conn: conn} do
      service_account = %ServiceAccount{
        id: "sa_123",
        name: "Test Account",
        description: "Test",
        created_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z],
        deactivated: false
      }

      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:ok, service_account}
      end)

      expect(ServiceAccountMock, :regenerate_token, fn "sa_123" ->
        {:ok, "new_api_token_456"}
      end)

      conn = post(conn, "/service_accounts/sa_123/regenerate_token")

      assert json_response(conn, 200) == %{"api_token" => "new_api_token_456"}
    end

    test "handles regenerate errors", %{conn: conn} do
      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:error, "Not found"}
      end)

      conn = post(conn, "/service_accounts/sa_123/regenerate_token")

      assert json_response(conn, 422) == %{"error" => "Not found"}
    end
  end
end
