defmodule Rbac.Service.OrganizationDeleted.Test do
  use Rbac.RepoCase

  @user_id "cb358a11-4185-4b5b-8829-5619805ac1fe"
  @org_id "7ae898b3-c511-4968-9641-fc8acda34853"
  @project_id "2628268c-6ec8-4282-add2-c39df4473aeb"

  setup do
    Support.Factories.RbacUser.insert(@user_id)
    {:ok, org_scope} = Support.Factories.Scope.insert("org_scope")
    {:ok, project_scope} = Support.Factories.Scope.insert("project_scope")

    {:ok, org_role} =
      Support.Factories.RbacRole.insert(
        scope_id: Map.get(org_scope, :id),
        org_id: @org_id
      )

    {:ok, project_role} =
      Support.Factories.RbacRole.insert(
        scope_id: Map.get(project_scope, :id),
        org_id: @org_id
      )

    Support.Factories.RolePermissionBinding.insert(rbac_role_id: org_role.id)
    Support.Factories.RolePermissionBinding.insert(rbac_role_id: project_role.id)

    Support.Factories.OrgRoleToProjRoleMappings.insert(
      org_role_id: org_role.id,
      proj_role_id: project_role.id
    )

    Support.Factories.RoleInheritance.insert(
      inheriting_role_id: org_role.id,
      inherited_role_id: project_role.id
    )

    Support.Factories.RepoToRoleMapping.insert(
      org_id: @org_id,
      admin_role_id: project_role.id,
      push_role_id: project_role.id,
      pull_role_id: project_role.id
    )

    Support.Factories.SubjectRoleBinding.insert(
      subject_id: @user_id,
      org_id: @org_id,
      role_id: org_role.id
    )

    Support.Factories.SubjectRoleBinding.insert(
      subject_id: @user_id,
      org_id: @org_id,
      project_id: @project_id,
      role_id: project_role.id
    )

    {:ok, %{}}
  end

  describe ".handle_message" do
    test "message processing when the server is avaible" do
      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 2
      assert Rbac.Repo.aggregate(Rbac.Repo.RbacRole, :count, :id) == 2

      publish_event(@org_id)

      :timer.sleep(300)

      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 0
      assert Rbac.Repo.aggregate(Rbac.Repo.RbacRole, :count, :id) == 0
    end
  end

  #
  # Helpers
  #

  defp publish_event(org_id) do
    event = %InternalApi.Organization.OrganizationDeleted{org_id: org_id}

    message = InternalApi.Organization.OrganizationDeleted.encode(event)

    options = %{
      url: Application.get_env(:rbac, :amqp_url),
      exchange: "organization_exchange",
      routing_key: "deleted"
    }

    Tackle.publish(message, options)
  end
end
