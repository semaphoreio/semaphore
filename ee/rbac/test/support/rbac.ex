defmodule Support.Rbac do
  alias Rbac.RoleBindingIdentification, as: RBI
  alias Rbac.RoleManagement

  @member_permissions ["organization.view"]
  @org_admin_permissions @member_permissions ++ ["organization.general_settings.manage"]
  @owner_permissions @org_admin_permissions ++ ["organization.delete"]
  @billing_admin_permissions ["organization.billing.manage"]

  @reader_permissions ["project.view"]
  @contributor_permissions @reader_permissions ++
                             [
                               "project.workflow.manage",
                               "project.scheduler.view",
                               "project.job.rerun"
                             ]
  @proj_admin_permissions @contributor_permissions ++
                            ["project.general_settings.manage", "project.delete"]

  def create_org_roles(org_id) do
    create_permissions("org_scope", @owner_permissions ++ @billing_admin_permissions)

    create_roles(
      org_id,
      "org_scope",
      [
        {"Member", @member_permissions},
        {"Admin", @org_admin_permissions},
        {"Owner", @owner_permissions},
        {"BillingAdmin", @billing_admin_permissions}
      ]
    )
  end

  def create_project_roles(org_id) do
    create_permissions("project_scope", @proj_admin_permissions)

    create_roles(
      org_id,
      "project_scope",
      [
        {"Reader", @reader_permissions},
        {"Contributor", @contributor_permissions},
        {"Admin", @proj_admin_permissions}
      ]
    )
  end

  def assign_org_role(org_id, user_id, role) do
    {:ok, rbi} = RBI.new(user_id: user_id, org_id: org_id)
    {:ok, nil} = RoleManagement.assign_role(rbi, role.id, :manually_assigned)
  end

  def assign_org_role_by_name(org_id, user_id, name, source \\ :manually_assigned) do
    {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name(name, "org_scope", org_id)
    {:ok, rbi} = RBI.new(user_id: user_id, org_id: org_id)
    {:ok, nil} = RoleManagement.assign_role(rbi, role.id, source)
  end

  def assign_project_role(org_id, user_id, prj_id, role) do
    {:ok, rbi} = RBI.new(user_id: user_id, org_id: org_id, project_id: prj_id)
    {:ok, nil} = RoleManagement.assign_role(rbi, role.id, :manually_assigned)
  end

  def assign_project_role_by_name(org_id, user_id, prj_id, name, source \\ :manually_assigned) do
    {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name(name, "project_scope", org_id)
    {:ok, rbi} = RBI.new(user_id: user_id, org_id: org_id, project_id: prj_id)
    {:ok, nil} = RoleManagement.assign_role(rbi, role.id, source)
  end

  defp create_permissions(scope_name, permission_names) do
    scope = fetch_or_create_scope(scope_name)

    permission_names
    |> Enum.each(fn permission_name ->
      Support.Factories.Permission.insert(name: permission_name, scope_id: scope.id)
    end)
  end

  defp create_roles(org_id, scope_name, role_permission_tuples) do
    scope = fetch_or_create_scope(scope_name)

    role_permission_tuples
    |> Enum.map(fn tuple = {role_name, _} -> {role_name, create_role(org_id, scope, tuple)} end)
    |> Enum.into(%{})
  end

  defp create_role(org_id, scope, {role_name, role_permissions}) do
    {:ok, role} =
      Support.Factories.RbacRole.insert(
        scope_id: scope.id,
        org_id: org_id,
        name: role_name
      )

    role_permissions
    |> Enum.map(fn permission_name ->
      Rbac.Repo.Permission.get_permission_id(permission_name)
    end)
    |> Enum.each(fn permission_id ->
      Support.Factories.RolePermissionBinding.insert(
        rbac_role_id: role.id,
        permission_id: permission_id
      )
    end)

    role
  end

  defp fetch_or_create_scope(scope_name) do
    case Rbac.Repo.Scope.get_scope_by_name(scope_name) do
      nil ->
        {:ok, scope} = Support.Factories.Scope.insert(scope_name)
        scope

      scope ->
        scope
    end
  end
end
