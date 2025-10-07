defmodule FrontWeb.EphemeralEnvironmentControllerTest do
  use FrontWeb.ConnCase
  import Mox
  alias Support.Stubs.DB
  alias InternalApi.EphemeralEnvironments.{EphemeralEnvironmentType, TypeState}

  setup :verify_on_exit!

  setup %{conn: conn} do
    Cacheman.clear(:front)
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    original_client = Application.get_env(:front, :ephemeral_environments_client)
    Application.put_env(:front, :ephemeral_environments_client, {EphemeralEnvironmentMock, []})

    on_exit(fn ->
      Application.put_env(:front, :ephemeral_environments_client, original_client)
    end)

    user_id = DB.first(:users) |> Map.get(:id)
    org_id = DB.first(:organizations) |> Map.get(:id)

    Support.Stubs.PermissionPatrol.remove_all_permissions()

    Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
      "organization.view",
      "organization.ephemeral_environments.view"
    ])

    Support.Stubs.Feature.setup_feature("ephemeral_environments", state: :ENABLED, quantity: 1)
    Support.Stubs.Feature.enable_feature(org_id, "ephemeral_environments")

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    {:ok, conn: conn, org_id: org_id, user_id: user_id}
  end

  describe "GET /ephemeral_environments" do
    test "lists ephemeral environment types successfully", %{conn: conn, org_id: org_id} do
      environment_type = %EphemeralEnvironmentType{
        id: "ee_123",
        org_id: org_id,
        name: "Test Environment",
        description: "Test description",
        created_by: "user_123",
        last_updated_by: "user_123",
        created_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        state: TypeState.value(:TYPE_STATE_READY),
        max_number_of_instances: 5
      }

      expect(EphemeralEnvironmentMock, :list, fn ^org_id, "" ->
        {:ok, [environment_type]}
      end)

      conn = get(conn, "/ephemeral_environments", format: "json")

      assert json_response(conn, 200) == %{
               "environment_types" => [
                 %{
                   "id" => "ee_123",
                   "org_id" => org_id,
                   "name" => "Test Environment",
                   "description" => "Test description",
                   "created_by" => "user_123",
                   "last_updated_by" => "user_123",
                   "created_at" => "2024-01-01T10:00:00Z",
                   "updated_at" => "2024-01-01T10:00:00Z",
                   "state" => "ready",
                   "maxInstances" => 5,
                   "stages" => [],
                   "environmentContext" => [],
                   "projectAccess" => [],
                   "ttlConfig" => %{"default_ttl_hours" => nil, "allow_extension" => false}
                 }
               ]
             }
    end

    test "returns error when list fails", %{conn: conn, org_id: org_id} do
      expect(EphemeralEnvironmentMock, :list, fn ^org_id, "" ->
        {:error, "Failed to list environment types"}
      end)

      conn = get(conn, "/ephemeral_environments", format: "json")

      assert json_response(conn, 422) == %{
               "error" => "Failed to list ephemeral environments"
             }
    end

    test "requires view permission", %{conn: conn, org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.remove_all_permissions()
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, ["organization.view"])

      conn = get(conn, "/ephemeral_environments", format: "json")
      assert response(conn, 404)
    end
  end

  describe "POST /ephemeral_environments" do
    test "creates ephemeral environment type successfully", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.ephemeral_environments.manage"
      ])

      expect(EphemeralEnvironmentMock, :create, fn environment_type ->
        assert environment_type.name == "New Environment"
        assert environment_type.description == "New environment description"
        assert environment_type.org_id == org_id
        assert environment_type.created_by == user_id
        assert environment_type.max_number_of_instances == 3

        {:ok,
         %{
           environment_type
           | id: "ee_new_123",
             created_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
             updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200}
         }}
      end)

      conn =
        post(conn, "/ephemeral_environments", %{
          "name" => "New Environment",
          "description" => "New environment description",
          "max_instances" => 3
        })

      response = json_response(conn, 201)

      assert response["id"] == "ee_new_123"
      assert response["name"] == "New Environment"
      assert response["description"] == "New environment description"
      assert response["maxInstances"] == 3
      assert response["state"] == "draft"
    end

    test "returns error when create fails", %{conn: conn, org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.ephemeral_environments.manage"
      ])

      expect(EphemeralEnvironmentMock, :create, fn _environment_type ->
        {:error, "Name is required"}
      end)

      conn =
        post(conn, "/ephemeral_environments", %{
          "name" => "",
          "description" => "Test"
        })

      assert json_response(conn, 422) == %{
               "error" => "Failed to create ephemeral environment"
             }
    end

    test "requires manage permission", %{conn: conn} do
      conn =
        post(conn, "/ephemeral_environments", %{
          "name" => "Test",
          "description" => "Test"
        })

      assert response(conn, 404)
    end
  end

  describe "PUT /ephemeral_environments/:id" do
    test "updates ephemeral environment type successfully", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.ephemeral_environments.manage"
      ])

      expect(EphemeralEnvironmentMock, :update, fn environment_type ->
        assert environment_type.id == "ee_123"
        assert environment_type.name == "Updated Environment"
        assert environment_type.description == "Updated description"
        assert environment_type.max_number_of_instances == 10

        {:ok,
         %{
           environment_type
           | updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200}
         }}
      end)

      conn =
        put(conn, "/ephemeral_environments/ee_123", %{
          "name" => "Updated Environment",
          "description" => "Updated description",
          "max_instances" => 10,
          "state" => "ready"
        })

      response = json_response(conn, 200)

      assert response["id"] == "ee_123"
      assert response["name"] == "Updated Environment"
      assert response["description"] == "Updated description"
      assert response["maxInstances"] == 10
    end

    test "returns error when update fails", %{conn: conn, org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.ephemeral_environments.manage"
      ])

      expect(EphemeralEnvironmentMock, :update, fn _environment_type ->
        {:error, "Environment type not found"}
      end)

      conn =
        put(conn, "/ephemeral_environments/ee_123", %{
          "name" => "Updated",
          "description" => "Updated"
        })

      assert json_response(conn, 422) == %{
               "error" => "Failed to update ephemeral environment"
             }
    end
  end

  describe "DELETE /ephemeral_environments/:id" do
    test "deletes ephemeral environment type successfully", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.ephemeral_environments.manage"
      ])

      expect(EphemeralEnvironmentMock, :delete, fn "ee_123", ^org_id ->
        :ok
      end)

      conn = delete(conn, "/ephemeral_environments/ee_123")

      assert response(conn, 204) == ""
    end

    test "returns error when delete fails", %{conn: conn, org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.ephemeral_environments.manage"
      ])

      expect(EphemeralEnvironmentMock, :delete, fn "ee_123", ^org_id ->
        {:error, "Environment type not found"}
      end)

      conn = delete(conn, "/ephemeral_environments/ee_123")

      assert json_response(conn, 422) == %{
               "error" => "Failed to delete ephemeral environment"
             }
    end
  end

  describe "POST /ephemeral_environments/:id/cordon" do
    test "cordons ephemeral environment type successfully", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.ephemeral_environments.manage"
      ])

      cordoned_type = %EphemeralEnvironmentType{
        id: "ee_123",
        org_id: org_id,
        name: "Test Environment",
        description: "Test description",
        created_by: "user_123",
        last_updated_by: user_id,
        created_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_200},
        updated_at: %Google.Protobuf.Timestamp{seconds: 1_704_103_300},
        state: TypeState.value(:TYPE_STATE_CORDONED),
        max_number_of_instances: 5
      }

      expect(EphemeralEnvironmentMock, :cordon, fn "ee_123", ^org_id ->
        {:ok, cordoned_type}
      end)

      conn = post(conn, "/ephemeral_environments/ee_123/cordon")

      response = json_response(conn, 200)

      assert response["id"] == "ee_123"
      assert response["state"] == "cordoned"
    end

    test "returns error when cordon fails", %{conn: conn, org_id: org_id, user_id: user_id} do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.ephemeral_environments.manage"
      ])

      expect(EphemeralEnvironmentMock, :cordon, fn "ee_123", ^org_id ->
        {:error, "Environment type not found"}
      end)

      conn = post(conn, "/ephemeral_environments/ee_123/cordon")

      assert json_response(conn, 422) == %{
               "error" => "Failed to cordon ephemeral environment"
             }
    end
  end

  describe "feature flag" do
    test "returns 404 when feature is disabled", %{conn: conn, org_id: org_id} do
      Support.Stubs.Feature.disable_feature(org_id, "ephemeral_environments")

      conn = get(conn, "/ephemeral_environments")
      assert response(conn, 404)
    end
  end
end
