defmodule FrontWeb.ServiceAccountControllerTest do
  use FrontWeb.ConnCase
  import Mox
  alias Support.Stubs.DB

  setup :verify_on_exit!

  setup %{conn: conn} do
    Cacheman.clear(:front)
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    original_client = Application.get_env(:front, :service_account_client)
    Application.put_env(:front, :service_account_client, {ServiceAccountMock, []})

    on_exit(fn ->
      Application.put_env(:front, :service_account_client, original_client)
    end)

    user_id = DB.first(:users) |> Map.get(:id)
    org_id = DB.first(:organizations) |> Map.get(:id)

    Support.Stubs.PermissionPatrol.remove_all_permissions()

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
      GrpcMock.expect(RBACMock, :list_members, fn request, _stream ->
        member = %InternalApi.RBAC.ListMembersResponse.Member{
          subject: %InternalApi.RBAC.Subject{
            subject_id: "sa_123",
            subject_type: InternalApi.RBAC.SubjectType.value(:SERVICE_ACCOUNT),
            display_name: ""
          },
          subject_role_bindings: [
            %InternalApi.RBAC.SubjectRoleBinding{
              role: %InternalApi.RBAC.Role{
                id: "role_123",
                name: "Admin",
                org_id: org_id,
                scope: InternalApi.RBAC.Scope.value(:SCOPE_ORG),
                description: "",
                permissions: [],
                rbac_permissions: [],
                readonly: false
              },
              source: InternalApi.RBAC.RoleBindingSource.value(:ROLE_BINDING_SOURCE_MANUALLY)
            }
          ]
        }

        assert request.org_id == org_id
        assert request.page.page_no == 0
        assert request.page.page_size == 20
        assert request.member_type == InternalApi.RBAC.SubjectType.value(:SERVICE_ACCOUNT)

        response = %InternalApi.RBAC.ListMembersResponse{
          members: [member],
          total_pages: 1
        }

        response
      end)

      service_account_proto = %InternalApi.ServiceAccount.ServiceAccount{
        id: "sa_123",
        name: "Test Service Account",
        description: "Test description",
        org_id: org_id,
        creator_id: "",
        created_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        deactivated: false
      }

      expect(ServiceAccountMock, :describe_many, fn ["sa_123"] ->
        {:ok, [service_account_proto]}
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
                   "deactivated" => false,
                   "roles" => [
                     %{
                       "id" => "role_123",
                       "name" => "Admin",
                       "source" => "manual",
                       "color" => "blue"
                     }
                   ]
                 }
               ],
               "total_pages" => 1
             }
    end

    test "handles pagination parameters", %{conn: conn, org_id: org_id} do
      GrpcMock.expect(RBACMock, :list_members, fn request, _stream ->
        assert request.org_id == org_id
        assert request.page.page_no == 1
        assert request.page.page_size == 20
        assert request.member_type == InternalApi.RBAC.SubjectType.value(:SERVICE_ACCOUNT)

        response = %InternalApi.RBAC.ListMembersResponse{
          members: [],
          total_pages: 2
        }

        response
      end)

      expect(ServiceAccountMock, :describe_many, fn [] ->
        {:ok, []}
      end)

      conn = get(conn, "/service_accounts", %{"page" => "2"})

      assert json_response(conn, 200) == %{
               "service_accounts" => [],
               "total_pages" => 2
             }
    end

    test "handles backend errors", %{conn: conn} do
      GrpcMock.expect(RBACMock, :list_members, fn _request, _stream ->
        raise GRPC.RPCError, status: 2, message: "Internal Server Error"
      end)

      conn = get(conn, "/service_accounts")

      assert json_response(conn, 422) ==
               %{"error" => "Failed to list service accounts"}
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
      service_account_proto = %InternalApi.ServiceAccount.ServiceAccount{
        id: "sa_new",
        name: "New Service Account",
        description: "New description",
        org_id: org_id,
        creator_id: user_id,
        created_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        deactivated: false
      }

      expect(ServiceAccountMock, :create, fn ^org_id,
                                             "New Service Account",
                                             "New description",
                                             ^user_id ->
        {:ok, {service_account_proto, "api_token_123"}}
      end)

      GrpcMock.expect(RBACMock, :assign_role, fn request, _stream ->
        assert request.role_assignment.subject.subject_id == "sa_new"
        assert request.role_assignment.role_id == "role_123"
        assert request.role_assignment.org_id == org_id
        assert request.requester_id == user_id

        %InternalApi.RBAC.AssignRoleResponse{}
      end)

      conn =
        post(conn, "/service_accounts", %{
          "name" => "New Service Account",
          "description" => "New description",
          "role_id" => "role_123"
        })

      assert json_response(conn, 201) == %{
               "id" => "sa_new",
               "name" => "New Service Account",
               "description" => "New description",
               "created_at" => "2024-01-01T10:00:00Z",
               "updated_at" => "2024-01-01T10:00:00Z",
               "deactivated" => false,
               "api_token" => "api_token_123",
               "roles" => []
             }
    end

    test "handles empty parameters", %{conn: conn, org_id: org_id, user_id: user_id} do
      expect(ServiceAccountMock, :create, fn ^org_id, "", "", ^user_id ->
        {:error, "Service account name cannot be empty"}
      end)

      conn = post(conn, "/service_accounts", %{})

      assert json_response(conn, 422) == %{
               "error" => "Failed to create service account or assign role"
             }
    end

    test "handles backend errors", %{conn: conn, org_id: org_id, user_id: user_id} do
      expect(ServiceAccountMock, :create, fn ^org_id, "Test", "Desc", ^user_id ->
        {:error, "Backend error"}
      end)

      conn =
        post(conn, "/service_accounts", %{
          "name" => "Test",
          "description" => "Desc"
        })

      assert json_response(conn, 422) == %{
               "error" => "Failed to create service account or assign role"
             }
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

  describe "PUT /service_accounts/:id" do
    setup %{org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.service_accounts.manage"
      ])

      :ok
    end

    test "updates service account successfully", %{conn: conn, user_id: user_id, org_id: org_id} do
      updated_account_proto = %InternalApi.ServiceAccount.ServiceAccount{
        id: "sa_123",
        name: "Updated Name",
        description: "Updated description",
        org_id: org_id,
        creator_id: "some_creator",
        created_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_189_600},
        deactivated: false
      }

      expect(ServiceAccountMock, :update, fn "sa_123", "Updated Name", "Updated description" ->
        {:ok, updated_account_proto}
      end)

      GrpcMock.expect(RBACMock, :assign_role, fn request, _stream ->
        assert request.role_assignment.subject.subject_id == "sa_123"
        assert request.role_assignment.role_id == "role_456"
        assert request.role_assignment.org_id == org_id
        assert request.requester_id == user_id

        %InternalApi.RBAC.AssignRoleResponse{}
      end)

      conn =
        put(conn, "/service_accounts/sa_123", %{
          "name" => "Updated Name",
          "description" => "Updated description",
          "role_id" => "role_456"
        })

      assert json_response(conn, 200) == %{
               "id" => "sa_123",
               "name" => "Updated Name",
               "description" => "Updated description",
               "created_at" => "2024-01-01T10:00:00Z",
               "updated_at" => "2024-01-02T10:00:00Z",
               "deactivated" => false,
               "roles" => []
             }
    end

    test "handles update errors", %{conn: conn} do
      expect(ServiceAccountMock, :update, fn "sa_123", "", "" ->
        {:error, "Service account name cannot be empty"}
      end)

      conn = put(conn, "/service_accounts/sa_123", %{})

      assert json_response(conn, 422) == %{
               "error" => "Failed to update service account or assign role"
             }
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
      service_account_proto = %InternalApi.ServiceAccount.ServiceAccount{
        id: "sa_123",
        name: "To Delete",
        description: "Will be deleted",
        org_id: "some_org_id",
        creator_id: "some_creator",
        created_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        deactivated: false
      }

      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:ok, service_account_proto}
      end)

      expect(ServiceAccountMock, :delete, fn "sa_123" ->
        :ok
      end)

      conn = delete(conn, "/service_accounts/sa_123")

      assert response(conn, 204) == ""
    end

    test "handles delete errors", %{conn: conn} do
      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:error, "Service account not found"}
      end)

      conn = delete(conn, "/service_accounts/sa_123")

      assert json_response(conn, 422) == %{"error" => "Failed to delete service account"}
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
      service_account_proto = %InternalApi.ServiceAccount.ServiceAccount{
        id: "sa_123",
        name: "Test Account",
        description: "Test",
        org_id: "some_org_id",
        creator_id: "some_creator",
        created_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        deactivated: false
      }

      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:ok, service_account_proto}
      end)

      expect(ServiceAccountMock, :regenerate_token, fn "sa_123" ->
        {:ok, "new_api_token_456"}
      end)

      conn = post(conn, "/service_accounts/sa_123/regenerate_token")

      assert json_response(conn, 200) == %{"api_token" => "new_api_token_456"}
    end

    test "handles regenerate errors", %{conn: conn} do
      expect(ServiceAccountMock, :describe, fn "sa_123" ->
        {:error, "Service account not found"}
      end)

      conn = post(conn, "/service_accounts/sa_123/regenerate_token")

      assert json_response(conn, 422) == %{
               "error" => "Failed to regenerate service account token"
             }
    end
  end
end
