defmodule InternalClients.PermissionsTest do
  use ExUnit.Case

  import Mock

  describe "has? with permission patrol" do
    setup do
      Application.put_env(:public_api, :use_rbac_api, false)
    end

    test "When permission patrol crashes, every permission is false" do
      GrpcMock.stub(PermissionPatrolMock, :has_permissions, fn _req, _stream ->
        raise(GRPC.RPCError,
          status: GRPC.Status.internal()
        )
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      permissions = ["organization.view", "organization.delete"]

      with_mocks([{Watchman, [:passthrough], [increment: fn _ -> nil end]}]) do
        has_permissions = InternalClients.Permissions.has?(user_id, org_id, permissions)

        assert_called_exactly(Watchman.increment("has_permissions.failure"), 1)
        assert has_permissions["organization.view"] == false
        assert has_permissions["organization.delete"] == false
      end
    end

    test "When permission patrol does not respond in time, every permission is false" do
      GrpcMock.stub(PermissionPatrolMock, :has_permissions, fn req, _stream ->
        :timer.sleep(5_000)

        %InternalApi.PermissionPatrol.HasPermissionsResponse{
          has_permissions:
            Enum.reduce(req.permissions, %{}, fn permission, acc ->
              Map.put(acc, permission, true)
            end)
        }
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      permissions = ["organization.view", "organization.delete"]

      with_mocks([{Watchman, [:passthrough], [increment: fn _ -> nil end]}]) do
        has_permissions = InternalClients.Permissions.has?(user_id, org_id, permissions)

        assert_called_exactly(Watchman.increment("has_permissions.failure"), 1)
        assert has_permissions["organization.view"] == false
        assert has_permissions["organization.delete"] == false
      end
    end

    test "One permission is present, another isn't" do
      GrpcMock.stub(PermissionPatrolMock, :has_permissions, fn _req, _stream ->
        %InternalApi.PermissionPatrol.HasPermissionsResponse{
          has_permissions: %{
            "organization.view" => true,
            "organization.delete" => false
          }
        }
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      permissions = ["organization.view", "organization.delete"]

      has_permissions = InternalClients.Permissions.has?(user_id, org_id, permissions)

      assert has_permissions["organization.view"] == true
      assert has_permissions["organization.delete"] == false
    end

    test "Only one permission is asked for" do
      GrpcMock.stub(PermissionPatrolMock, :has_permissions, fn _req, _stream ->
        %InternalApi.PermissionPatrol.HasPermissionsResponse{
          has_permissions: %{
            "organization.view" => true
          }
        }
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      permissions = "organization.view"

      has_permissions = InternalClients.Permissions.has?(user_id, org_id, permissions)

      assert has_permissions == true
    end

    test "when user_id is nil and only one permissions is passed" do
      resp = InternalClients.Permissions.has?(nil, Ecto.UUID.generate(), "organization.view")
      assert resp == false
    end

    test "when user_id is nil and multiple permissions are passed" do
      permissions = ["organization.view", "organization.delete"]
      resp = InternalClients.Permissions.has?(nil, Ecto.UUID.generate(), permissions)

      assert resp["organization.view"] == false
      assert resp["organization.delete"] == false
    end

    test "when user_id is '' and only one permissions is passed" do
      resp = InternalClients.Permissions.has?("", Ecto.UUID.generate(), "organization.view")
      assert resp == false
    end
  end

  describe "has? with rbac API" do
    setup do
      Application.put_env(:public_api, :use_rbac_api, true)

      on_exit(fn ->
        Application.put_env(:public_api, :use_rbac_api, false)
      end)
    end

    test "When RBAC API crashes, every permission is false" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _req, _stream ->
        raise(GRPC.RPCError,
          status: GRPC.Status.internal()
        )
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      permissions = ["organization.view", "organization.delete"]

      with_mocks([{Watchman, [:passthrough], [increment: fn _ -> nil end]}]) do
        has_permissions = InternalClients.Permissions.has?(user_id, org_id, permissions)

        assert_called_exactly(Watchman.increment("has_permissions.failure"), 1)
        assert has_permissions["organization.view"] == false
        assert has_permissions["organization.delete"] == false
      end
    end

    test "When RBAC API does not respond in time, every permission is false" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        :timer.sleep(5_000)

        %InternalApi.RBAC.ListUserPermissionsResponse{
          permissions: ["organization.view", "organization.delete"]
        }
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      permissions = ["organization.view", "organization.delete"]

      with_mocks([{Watchman, [:passthrough], [increment: fn _ -> nil end]}]) do
        has_permissions = InternalClients.Permissions.has?(user_id, org_id, permissions)

        assert_called_exactly(Watchman.increment("has_permissions.failure"), 1)
        assert has_permissions["organization.view"] == false
        assert has_permissions["organization.delete"] == false
      end
    end

    test "One permission is present, another isn't" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _req, _stream ->
        %InternalApi.RBAC.ListUserPermissionsResponse{permissions: ["organization.view"]}
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      permissions = ["organization.view", "organization.delete"]

      has_permissions = InternalClients.Permissions.has?(user_id, org_id, permissions)

      assert has_permissions["organization.view"] == true
      assert has_permissions["organization.delete"] == false
    end

    test "Only one permission is asked for" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _req, _stream ->
        %InternalApi.RBAC.ListUserPermissionsResponse{
          permissions: ["organization.view", "organization.delete"]
        }
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      permissions = "organization.view"

      has_permissions = InternalClients.Permissions.has?(user_id, org_id, permissions)

      assert has_permissions == true
    end

    test "No permission is asked for -> all permissions in RBAC response are used" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _req, _stream ->
        %InternalApi.RBAC.ListUserPermissionsResponse{
          permissions: ["organization.view", "organization.delete"]
        }
      end)

      user_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      has_permissions = InternalClients.Permissions.has?(user_id, org_id, [])
      assert has_permissions["organization.view"] == true
      assert has_permissions["organization.delete"] == true
    end

    test "when user_id is nil and only one permissions is passed" do
      resp = InternalClients.Permissions.has?(nil, Ecto.UUID.generate(), "organization.view")
      assert resp == false
    end

    test "when user_id is nil and multiple permissions are passed" do
      permissions = ["organization.view", "organization.delete"]
      resp = InternalClients.Permissions.has?(nil, Ecto.UUID.generate(), permissions)

      assert resp["organization.view"] == false
      assert resp["organization.delete"] == false
    end

    test "when user_id is '' and only one permissions is passed" do
      resp = InternalClients.Permissions.has?("", Ecto.UUID.generate(), "organization.view")
      assert resp == false
    end
  end
end
