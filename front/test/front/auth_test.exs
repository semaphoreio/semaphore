defmodule Front.AuthTest do
  use ExUnit.Case

  import Mock

  setup do
    {:ok,
     %{
       org_id: Ecto.UUID.generate(),
       user_id: Ecto.UUID.generate()
     }}
  end

  describe ".read_organization?" do
    test "has permission -> true", ctx do
      Support.Stubs.PermissionPatrol.allow_everything(ctx.org_id, ctx.user_id)
      assert Front.Auth.read_organization?(ctx.user_id, ctx.org_id)
    end

    test "no permission -> false", ctx do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.allow_everything_except(ctx.org_id, ctx.user_id, [
        "organization.view"
      ])

      refute Front.Auth.read_organization?(ctx.user_id, ctx.org_id)
    end
  end

  describe ".update_project?" do
    test "has permission -> true", ctx do
      Support.Stubs.PermissionPatrol.allow_everything(ctx.org_id, ctx.user_id)
      assert Front.Auth.update_project?(ctx.user_id, Ecto.UUID.generate(), ctx.org_id)
    end

    test "no permission -> false", ctx do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.allow_everything_except(ctx.org_id, ctx.user_id, [
        "project.general_settings.manage"
      ])

      refute Front.Auth.update_project?(ctx.user_id, Ecto.UUID.generate(), ctx.org_id)
    end
  end

  describe ".delete_project?" do
    test "has permission -> true", ctx do
      Support.Stubs.PermissionPatrol.allow_everything(ctx.org_id, ctx.user_id)
      assert Front.Auth.delete_project?(ctx.user_id, Ecto.UUID.generate(), ctx.org_id)
    end

    test "no permission -> false", ctx do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.allow_everything_except(ctx.org_id, ctx.user_id, [
        "project.delete"
      ])

      refute Front.Auth.delete_project?(ctx.user_id, Ecto.UUID.generate(), ctx.org_id)
    end
  end

  describe ".manage_people?" do
    test "has permission -> true", ctx do
      Support.Stubs.PermissionPatrol.allow_everything(ctx.org_id, ctx.user_id)
      assert Front.Auth.manage_people?(ctx.user_id, ctx.org_id)
    end

    test "no permission -> false", ctx do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.allow_everything_except(ctx.org_id, ctx.user_id, [
        "organization.people.manage"
      ])

      refute Front.Auth.manage_people?(ctx.user_id, ctx.org_id)
    end
  end

  describe ".refresh_people" do
    test "it refresh people on all org projects in guard service" do
      GrpcMock.stub(RBACMock, :refresh_collaborators, fn req, _stream ->
        assert req.org_id == "123"

        InternalApi.RBAC.RefreshCollaboratorsResponse.new()
      end)

      assert Front.Auth.refresh_people("123") == {:ok, true}
    end
  end

  describe "is_authorized?" do
    test "only one org-scoped operations" do
      with_mocks([
        {Front.RBAC.Permissions, [],
         [
           has?: fn _user_id, _org_id, _project_id, ["organization.ip_allow_list.view"] ->
             %{"organization.ip_allow_list.view" => true}
           end
         ]}
      ]) do
        org_id = Ecto.UUID.generate()
        user_id = Ecto.UUID.generate()
        operation = :ViewOrganizationIpAllowList

        assert Front.Auth.is_authorized?(org_id, user_id, operation) == true

        assert_called_exactly(
          Front.RBAC.Permissions.has?(user_id, org_id, "", ["organization.ip_allow_list.view"]),
          1
        )
      end
    end

    test "mixed org-scoped and project-scoped operations" do
      with_mocks([
        {Front.RBAC.Permissions, [],
         [
           has?: fn _user_id, _org_id, project_id, [operation] ->
             if project_id == "" do
               %{operation => true}
             else
               %{operation => false}
             end
           end
         ]}
      ]) do
        org_id = Ecto.UUID.generate()
        user_id = Ecto.UUID.generate()
        project_id = Ecto.UUID.generate()

        operations = [
          %{name: :ViewOrganizationIpAllowList},
          %{name: :ViewProjectScheduler, project_id: project_id}
        ]

        resp = Front.Auth.is_authorized?(org_id, user_id, operations)
        assert resp[:ViewOrganizationIpAllowList] == true
        assert resp[:ViewProjectScheduler] == false

        assert_called_exactly(
          Front.RBAC.Permissions.has?(user_id, org_id, "", ["organization.ip_allow_list.view"]),
          1
        )

        assert_called_exactly(
          Front.RBAC.Permissions.has?(user_id, org_id, project_id, ["project.scheduler.view"]),
          1
        )
      end
    end
  end
end
