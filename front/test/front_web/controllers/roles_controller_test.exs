defmodule FrontWeb.RolesControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB
  @moduletag :rbac_roles

  @feature_name :rbac__custom_roles
  @test_org_permissions [
    "organization.contact_support",
    "organization.delete"
  ]
  @test_project_permissions [
    "project.delete",
    "project.access.view",
    "project.access.manage"
  ]

  describe "GET /roles" do
    setup [:setup_context, :authorize_view]

    test "disable 'New Role' button when custom roles feature is disabled", %{conn: conn} = ctx do
      disable_feature(ctx)

      assert html = html_response(call_index(conn), 200)
      assert html =~ "disabled"
      assert html =~ "title=\"Sorry, this feature is not enabled.\""
    end

    test "denies access for unauthorized requests", %{conn: conn} = ctx do
      setup_permissions(ctx, ["organization.view"])

      assert html = html_response(call_index(conn), 200)
      assert html =~ "Sorry, you can’t access roles."
      assert html =~ "Ask organization owner or any of the admins to give you access permission."
    end

    test "allows access for authorized requests", %{conn: conn} = _ctx do
      html = html_response(call_index(conn), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
    end

    test "renders pre-configured roles", %{conn: conn} = _ctx do
      html = html_response(call_index(conn), 200)
      default_roles = Support.Stubs.DB.all(:rbac_roles)

      assert html =~ "disabled"
      assert html =~ "You don&#39;t have permissions to create a new role."

      for default_role <- default_roles do
        assert html =~ "<span class=\"b\">#{default_role.name}</span>"
        refute edit_button_visible?(html, default_role.id)
        assert show_button_visible?(html, default_role.id)
      end
    end

    test "renders custom roles", %{conn: conn} = ctx do
      {:ok, new_ctx} = setup_custom_roles(ctx)
      html = html_response(call_index(conn), 200)

      assert html =~ "disabled"
      assert html =~ "You don&#39;t have permissions to create a new role."

      assert html =~ "<span class=\"b\">#{new_ctx.org_role.name}</span>"
      assert html =~ "#{length(@test_org_permissions) + 1} permissions"
      refute edit_button_visible?(html, new_ctx.org_role.id)
      assert show_button_visible?(html, new_ctx.org_role.id)

      assert html =~ "<span class=\"b\">#{new_ctx.project_role.name}</span>"
      assert html =~ "#{length(@test_project_permissions) + 1} permissions"
      refute edit_button_visible?(html, new_ctx.project_role.id)
      assert show_button_visible?(html, new_ctx.project_role.id)
    end

    test "renders edit buttons if user has manage permission", %{conn: conn} = ctx do
      default_roles = Support.Stubs.DB.all(:rbac_roles)
      {:ok, new_ctx} = setup_custom_roles(ctx)

      authorize_manage(ctx)
      html = html_response(call_index(conn), 200)

      for default_role <- default_roles do
        assert html =~ "<span class=\"b\">#{default_role.name}</span>"
        refute edit_button_visible?(html, default_role.id)
        assert show_button_visible?(html, default_role.id)
      end

      assert html =~ "New Role"

      assert html =~ "<span class=\"b\">#{new_ctx.org_role.name}</span>"
      assert html =~ "#{length(@test_org_permissions) + 1} permissions"
      assert edit_button_visible?(html, new_ctx.org_role.id)
      refute show_button_visible?(html, new_ctx.org_role.id)

      assert html =~ "<span class=\"b\">#{new_ctx.project_role.name}</span>"
      assert html =~ "#{length(@test_project_permissions) + 1} permissions"
      assert edit_button_visible?(html, new_ctx.project_role.id)
      refute show_button_visible?(html, new_ctx.project_role.id)
    end
  end

  describe "GET /roles/:role_id" do
    setup [:setup_context, :setup_custom_roles, :authorize_view]

    test "show role definition even if custom roles feature is disabled", %{conn: conn} = ctx do
      disable_feature(ctx)

      assert html_response(call_show(conn, ctx.org_role.id), 200)
      assert html_response(call_show(conn, ctx.project_role.id), 200)
    end

    test "denies access for unauthorized requests", %{conn: conn} = ctx do
      setup_permissions(ctx, ["organization.view"])

      assert html = html_response(call_show(conn, ctx.org_role.id), 200)
      assert html =~ "Sorry, you can’t access roles."
      assert html =~ "Ask organization owner or any of the admins to give you access permission."

      assert html = html_response(call_show(conn, ctx.project_role.id), 200)
      assert html =~ "Sorry, you can’t access roles."
      assert html =~ "Ask organization owner or any of the admins to give you access permission."
    end

    test "allows access for authorized requests", %{conn: conn} = ctx do
      assert html = html_response(call_show(conn, ctx.org_role.id), 200)
      assert html =~ "Role overview・Custom organization role"

      assert html = html_response(call_show(conn, ctx.project_role.id), 200)
      assert html =~ "Role overview・Custom project role"
    end

    test "renders 404 for non-existing role", %{conn: conn} = _ctx do
      assert html_response(call_show(conn, UUID.uuid4()), 404)
    end

    test "renders organization role settings", %{conn: conn, role: role} = ctx do
      html = html_response(call_show(conn, ctx.org_role.id), 200)
      assert html =~ "Custom organization role"
      assert html =~ "Description of a custom organization role"

      assert Enum.all?(@test_org_permissions, &permission_selected?(html, &1))
      assert permission_selected?(html, "organization.view")

      refute ctx.permissions
             |> Enum.filter(&String.starts_with?(&1, "organization."))
             |> Enum.reject(fn permission ->
               Enum.member?(@test_org_permissions, permission) ||
                 permission == "organization.view"
             end)
             |> Enum.any?(&permission_selected?(html, &1))

      assert role_mapping_set?(html, role)
      refute html =~ "Save changes"
      refute html =~ "Delete role"
    end

    test "renders project role settings", %{conn: conn} = ctx do
      html = html_response(call_show(conn, ctx.project_role.id), 200)
      assert html =~ "Custom project role"
      assert html =~ "Description of a custom project role"

      assert Enum.all?(@test_project_permissions, &permission_selected?(html, &1))
      assert permission_selected?(html, "project.view")

      refute ctx.permissions
             |> Enum.filter(&String.starts_with?(&1, "project."))
             |> Enum.reject(fn permission ->
               Enum.member?(@test_project_permissions, permission) || permission == "project.view"
             end)
             |> Enum.any?(&permission_selected?(html, &1))

      refute role_mapping_set?(html)
      refute html =~ "Save changes"
      refute html =~ "Delete role"
    end
  end

  describe "GET /roles/:scope/new" do
    setup [:setup_context, :authorize_manage]

    test "renders 404 when custom roles feature is disabled", %{conn: conn} = ctx do
      disable_feature(ctx)

      assert html_response(call_new(conn, "organization"), 404)
      assert html_response(call_new(conn, "project"), 404)
    end

    test "renders zero page when custom roles feature is in zero state", %{conn: conn} = ctx do
      zero_feature(ctx)

      assert html = html_response(call_new(conn, "organization"), 200)

      assert html =~
               "Sorry, your organization does not have access to manage roles."
    end

    test "denies access for unauthorized requests", %{conn: conn} = ctx do
      setup_permissions(ctx, ["organization.custom_roles.view"])

      assert html_response(call_new(conn, "organization"), 404)
      assert html_response(call_new(conn, "project"), 404)
    end

    test "allows access for authorized requests", %{conn: conn} = _ctx do
      html = html_response(call_new(conn, "organization"), 200)
      assert html =~ "Create a new role"

      html = html_response(call_new(conn, "project"), 200)
      assert html =~ "Create a new role"
    end

    test "renders form for creating an organization role", %{conn: conn} = ctx do
      html = html_response(call_new(conn, "organization"), 200)
      assert html =~ "Create a new role"

      assert html =~ "Name of a role"
      assert html =~ "Short description of a role"
      assert html =~ "Permissions"

      for permission <- Enum.filter(ctx.permissions, &String.starts_with?(&1, "organization.")) do
        assert html =~ permission

        unless permission == "organization.view",
          do: refute(permission_selected?(html, permission))
      end

      assert permission_selected?(html, "organization.view")
      assert html =~ "Project access"
      refute html =~ "Delete role"
      assert role_mapping_unset?(html)
    end

    test "renders form for creating a new project role", %{conn: conn} = ctx do
      html = html_response(call_new(conn, "project"), 200)
      assert html =~ "Create a new role"

      assert html =~ "Name of a role"
      assert html =~ "Short description of a role"
      assert html =~ "Permissions"

      for permission <- Enum.filter(ctx.permissions, &String.starts_with?(&1, "project.")) do
        assert html =~ permission

        unless permission == "project.view",
          do: refute(permission_selected?(html, permission))
      end

      assert permission_selected?(html, "project.view")
      refute html =~ "Project access"
      refute html =~ "Delete role"
    end

    test "renders 404 for non-existing scope", %{conn: conn} do
      assert html_response(call_new(conn, "non-existing-scope"), 404)
    end
  end

  describe "GET /roles/:role_id/edit" do
    setup [:setup_context, :setup_custom_roles, :authorize_manage]

    test "renders 404 when custom roles feature is disabled", %{conn: conn} = ctx do
      disable_feature(ctx)

      assert html_response(call_edit(conn, ctx.org_role.id), 404)
      assert html_response(call_edit(conn, ctx.project_role.id), 404)
    end

    test "renders zero page when custom roles feature is in zero state", %{conn: conn} = ctx do
      zero_feature(ctx)

      assert html = html_response(call_edit(conn, ctx.org_role.id), 200)

      assert html =~
               "Sorry, your organization does not have access to manage roles."
    end

    test "denies access for unauthorized requests", %{conn: conn} = ctx do
      setup_permissions(ctx, ["organization.custom_roles.view"])

      assert html_response(call_edit(conn, ctx.org_role.id), 404)
      assert html_response(call_edit(conn, ctx.project_role.id), 404)
    end

    test "allows access for authorized requests", %{conn: conn} = ctx do
      assert html = html_response(call_edit(conn, ctx.org_role.id), 200)
      assert html =~ "Edit role・Custom organization role"

      assert html = html_response(call_edit(conn, ctx.project_role.id), 200)
      assert html =~ "Edit role・Custom project role"
    end

    test "renders 404 for non-existing role", %{conn: conn} = _ctx do
      assert html_response(call_edit(conn, UUID.uuid4()), 404)
    end

    test "renders organization role settings", %{conn: conn, role: role} = ctx do
      html = html_response(call_edit(conn, ctx.org_role.id), 200)
      assert html =~ "Custom organization role"
      assert html =~ "Description of a custom organization role"

      assert Enum.all?(@test_org_permissions, &permission_selected?(html, &1))
      assert permission_selected?(html, "organization.view")

      refute ctx.permissions
             |> Enum.filter(&String.starts_with?(&1, "organization."))
             |> Enum.reject(fn permission ->
               Enum.member?(@test_org_permissions, permission) ||
                 permission == "organization.view"
             end)
             |> Enum.any?(&permission_selected?(html, &1))

      assert role_mapping_set?(html, role)
      assert html =~ "Save changes"
      assert html =~ "Delete role"
    end

    test "renders project role settings", %{conn: conn} = ctx do
      html = html_response(call_edit(conn, ctx.project_role.id), 200)
      assert html =~ "Custom project role"
      assert html =~ "Description of a custom project role"

      assert Enum.all?(@test_project_permissions, &permission_selected?(html, &1))
      assert permission_selected?(html, "project.view")

      refute ctx.permissions
             |> Enum.filter(&String.starts_with?(&1, "project."))
             |> Enum.reject(fn permission ->
               Enum.member?(@test_project_permissions, permission) || permission == "project.view"
             end)
             |> Enum.any?(&permission_selected?(html, &1))

      refute role_mapping_set?(html)
      assert html =~ "Save changes"
      assert html =~ "Delete role"
    end

    test "when role is readonly then renders show page", %{conn: conn} = ctx do
      html = html_response(call_edit(conn, ctx.role.id), 200)
      assert html =~ "value=\"#{ctx.role.name}\""
      assert html =~ ctx.role.description

      refute html =~ "Save changes"
      refute html =~ "Delete role"
    end
  end

  describe "POST /roles" do
    setup [:setup_context, :setup_params, :authorize_manage]

    test "renders 404 when custom roles feature is disabled", %{conn: conn} = ctx do
      disable_feature(ctx)

      assert html_response(call_create(conn, ctx.org_params), 404)
      assert html_response(call_create(conn, ctx.project_params), 404)
    end

    test "renders zero page when custom roles feature is in zero state", %{conn: conn} = ctx do
      zero_feature(ctx)

      assert html = html_response(call_create(conn, ctx.org_params), 200)

      assert html =~
               "Sorry, your organization does not have access to manage roles."
    end

    test "denies access for unauthorized requests", %{conn: conn} = ctx do
      setup_permissions(ctx, ["organization.custom_roles.view"])

      assert html_response(call_create(conn, ctx.org_params), 404)
      assert html_response(call_create(conn, ctx.project_params), 404)
    end

    test "creates a new organization role", %{conn: conn} = ctx do
      params = grant_permissions_in_params(ctx.org_params, ctx.org_permissions)
      assert conn = call_create(conn, params)
      assert redirected_to(conn, 302) =~ roles_path(conn, :index)
      assert get_flash(conn, :notice) =~ "Role created successfully"

      assert html = html_response(call_index(recycle(conn)), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
      assert html =~ "Another organization role name"
      assert html =~ "Custom organization role description"
      assert html =~ "#{length(ctx.org_permissions)} permissions"
    end

    test "creates a new project role", %{conn: conn} = ctx do
      params = grant_permissions_in_params(ctx.project_params, ctx.project_permissions)
      assert conn = call_create(conn, params)
      assert redirected_to(conn, 302) =~ roles_path(conn, :index)
      assert get_flash(conn, :notice) =~ "Role created successfully"

      assert html = html_response(call_index(recycle(conn)), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
      assert html =~ "Another project role name"
      assert html =~ "Custom project role description"
      assert html =~ "#{length(ctx.project_permissions)} permissions"
    end

    test "renders form with errors when validation fails", %{conn: conn} = ctx do
      params = grant_permissions_in_params(ctx.org_params, ctx.org_permissions)
      params = put_in(params, ["role", "name"], "")
      assert conn = call_create(conn, params)

      assert get_flash(conn, :alert) =~ "Check provided data for errors"
      assert html = html_response(conn, 200)

      assert html =~ "Create a new role"
      assert html =~ "can&#39;t be blank"
      assert html =~ "Custom organization role description"

      for permission <- ctx.org_permissions do
        assert permission_selected?(html, permission)
      end
    end

    test "renders form again when creation fails", %{conn: conn} = ctx do
      Support.Stubs.RBAC.Grpc.expect(:modify_role, fn ->
        raise GRPC.RPCError, status: :internal, message: "Role is not editable"
      end)

      params = grant_permissions_in_params(ctx.project_params, ["project.view"])
      assert conn = call_create(conn, params)
      assert get_flash(conn, :alert) =~ "Role is not editable"
      assert html = html_response(conn, 200)

      assert html =~ "Create a new role"
      assert html =~ "Another project role name"
      assert html =~ "Custom project role description"
      assert permission_selected?(html, "project.view")
    end
  end

  describe "PUT /roles/:role_id" do
    setup [:setup_context, :setup_custom_roles, :setup_params, :authorize_manage]

    test "renders 404 when custom roles feature is disabled", %{conn: conn} = ctx do
      disable_feature(ctx)

      assert html_response(call_update(conn, ctx.org_role.id, ctx.org_params), 404)
      assert html_response(call_update(conn, ctx.project_role.id, ctx.project_params), 404)
    end

    test "renders zero page when custom roles feature is in zero state", %{conn: conn} = ctx do
      zero_feature(ctx)

      assert html = html_response(call_update(conn, ctx.org_role.id, ctx.org_params), 200)

      assert html =~
               "Sorry, your organization does not have access to manage roles."
    end

    test "denies access for unauthorized requests", %{conn: conn} = ctx do
      setup_permissions(ctx, ["organization.custom_roles.view"])

      assert html_response(call_update(conn, ctx.org_role.id, ctx.org_params), 404)
      assert html_response(call_update(conn, ctx.project_role.id, ctx.project_params), 404)
    end

    test "updates an organization role", %{conn: conn} = ctx do
      params =
        grant_permissions_in_params(ctx.org_params, ctx.org_permissions -- @test_org_permissions)

      assert conn = call_update(conn, ctx.org_role.id, params)
      assert redirected_to(conn, 302) =~ roles_path(conn, :index)
      assert get_flash(conn, :notice) =~ "Role updated successfully"

      assert html = html_response(call_index(recycle(conn)), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
      assert html =~ "Another organization role name"
      assert html =~ "Custom organization role description"
      assert html =~ "#{length(ctx.org_permissions) - length(@test_org_permissions)} permissions"
    end

    test "allows role name to be unchanged an organization role", %{conn: conn} = ctx do
      params = put_in(ctx.org_params, ["role", "name"], ctx.org_role.name)
      params = grant_permissions_in_params(params, ctx.org_permissions -- @test_org_permissions)

      assert conn = call_update(conn, ctx.org_role.id, params)
      assert redirected_to(conn, 302) =~ roles_path(conn, :index)
      assert get_flash(conn, :notice) =~ "Role updated successfully"

      assert html = html_response(call_index(recycle(conn)), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
      assert html =~ "Custom organization role"
      assert html =~ "Custom organization role description"
      assert html =~ "#{length(ctx.org_permissions) - length(@test_org_permissions)} permissions"
    end

    test "updates a project role", %{conn: conn} = ctx do
      params =
        grant_permissions_in_params(
          ctx.project_params,
          ctx.project_permissions -- @test_project_permissions
        )

      assert conn = call_update(conn, ctx.project_role.id, params)
      assert redirected_to(conn, 302) =~ roles_path(conn, :index)
      assert get_flash(conn, :notice) =~ "Role updated successfully"

      assert html = html_response(call_index(recycle(conn)), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
      assert html =~ "Another project role name"
      assert html =~ "Custom project role description"

      assert html =~
               "#{length(ctx.project_permissions) - length(@test_project_permissions)} permissions"
    end

    test "renders form with errors when validation fails", %{conn: conn} = ctx do
      params = grant_permissions_in_params(ctx.project_params, ctx.project_permissions)
      params = put_in(params, ["role", "name"], "Contributor")
      assert conn = call_update(conn, ctx.project_role.id, params)

      assert get_flash(conn, :alert) =~ "Check provided data for errors"
      assert html = html_response(conn, 200)

      assert html =~ "Edit role・Custom project role"
      assert html =~ "Contributor"
      assert html =~ "has already been taken"
      assert html =~ "Custom project role description"

      for permission <- ctx.project_permissions do
        assert permission_selected?(html, permission)
      end
    end

    test "renders form again when creation fails", %{conn: conn} = ctx do
      Support.Stubs.RBAC.Grpc.expect(:modify_role, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unknown error"
      end)

      params = grant_permissions_in_params(ctx.org_params, ["organization.view"])
      assert conn = call_update(conn, ctx.org_role.id, params)
      assert get_flash(conn, :alert) =~ "Unknown error"
      assert html = html_response(conn, 200)

      assert html =~ "Edit role・Custom organization role"
      assert html =~ "Another organization role name"
      assert html =~ "Custom organization role description"

      assert permission_selected?(html, "organization.view")
    end
  end

  describe "DELETE /roles/:role_id" do
    setup [:setup_context, :setup_custom_roles, :authorize_manage]

    test "renders 404 when custom roles feature is disabled", %{conn: conn} = ctx do
      Support.Stubs.Feature.disable_feature(ctx.organization_id, @feature_name)

      on_exit(fn ->
        Support.Stubs.Feature.enable_feature(ctx.organization_id, @feature_name)
      end)

      assert html_response(call_delete(conn, ctx.org_role.id), 404)
      assert html_response(call_delete(conn, ctx.project_role.id), 404)
    end

    test "renders zero page when custom roles feature is in zero state", %{conn: conn} = ctx do
      Support.Stubs.Feature.zero_feature(ctx.organization_id, @feature_name)

      on_exit(fn ->
        Support.Stubs.Feature.enable_feature(ctx.organization_id, @feature_name)
      end)

      assert html = html_response(call_delete(conn, ctx.org_role.id), 200)

      assert html =~
               "Sorry, your organization does not have access to manage roles."
    end

    test "denies access for unauthorized requests", %{conn: conn} = ctx do
      setup_permissions(ctx, ["organization.custom_roles.view"])

      assert html_response(call_delete(conn, ctx.org_role.id), 404)
      assert html_response(call_delete(conn, ctx.project_role.id), 404)
    end

    test "deletes an organization role", %{conn: conn} = ctx do
      assert conn = call_delete(conn, ctx.org_role.id)
      assert redirected_to(conn, 302) =~ roles_path(conn, :index)
      assert get_flash(conn, :notice) =~ "Role removed successfully"

      assert html = html_response(call_index(recycle(conn)), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
      refute html =~ "Custom organization role"
    end

    test "deletes a project role", %{conn: conn} = ctx do
      assert conn = call_delete(conn, ctx.project_role.id)
      assert redirected_to(conn, 302) =~ roles_path(conn, :index)
      assert get_flash(conn, :notice) =~ "Role removed successfully"

      assert html = html_response(call_index(recycle(conn)), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
      refute html =~ "Custom project role"
    end

    test "renders index when deletion fails", %{conn: conn} = ctx do
      Support.Stubs.RBAC.Grpc.expect(:destroy_role, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unknown error"
      end)

      assert conn = call_delete(conn, ctx.org_role.id)
      assert redirected_to(conn, 302) =~ roles_path(conn, :index)
      assert get_flash(conn, :alert) =~ "Unknown error"

      assert html = html_response(call_index(recycle(conn)), 200)
      assert html =~ "<h2 class=\"f3 f2-m mb0\">Roles</h2>"
      assert html =~ "Custom project role"
    end
  end

  defp call_index(conn),
    do: get(conn, roles_path(conn, :index))

  defp call_show(conn, role_id),
    do: get(conn, roles_path(conn, :show, role_id))

  defp call_new(conn, scope),
    do: get(conn, roles_path(conn, :new, scope))

  defp call_edit(conn, role_id),
    do: get(conn, roles_path(conn, :edit, role_id))

  defp call_create(conn, params),
    do: post(conn, roles_path(conn, :create, params))

  defp call_update(conn, role_id, params),
    do: put(conn, roles_path(conn, :update, role_id, params))

  defp call_delete(conn, role_id),
    do: delete(conn, roles_path(conn, :delete, role_id))

  defp setup_context(_context) do
    Cacheman.clear(:front)
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()
    role = DB.first(:rbac_roles)
    permissions = DB.all(:permissions) |> MapSet.new(& &1.name)

    Support.Stubs.Feature.enable_feature(organization.id, @feature_name)
    Support.Stubs.Feature.enable_feature(organization.id, :permission_patrol)

    {:ok,
     [
       permissions: permissions,
       org_permissions: Enum.filter(permissions, &String.starts_with?(&1, "organization.")),
       project_permissions: Enum.filter(permissions, &String.starts_with?(&1, "project.")),
       organization: organization,
       organization_id: organization.id,
       user: user,
       user_id: user.id,
       role: role,
       role_id: role.id
     ]}
  end

  defp setup_permissions(context, permissions) do
    Support.Stubs.PermissionPatrol.remove_all_permissions()

    Support.Stubs.PermissionPatrol.add_permissions(
      context.organization_id,
      context.user_id,
      permissions
    )
  end

  defp setup_custom_roles(context) do
    {:ok,
     %{
       org_role:
         Support.Stubs.RBAC.add_role(
           context.organization_id,
           "Custom organization role",
           "org_scope",
           %{
             description: "Description of a custom organization role",
             permissions: @test_org_permissions,
             maps_to: context.role.id
           }
         ),
       project_role:
         Support.Stubs.RBAC.add_role(
           context.organization_id,
           "Custom project role",
           "project_scope",
           %{
             description: "Description of a custom project role",
             permissions: @test_project_permissions
           }
         )
     }}
  end

  defp authorize_view(context),
    do: authorize(context, ["organization.custom_roles.view"])

  defp authorize_manage(context),
    do: authorize(context, ["organization.custom_roles.view", "organization.custom_roles.manage"])

  defp authorize(context = %{conn: conn}, permissions) do
    {:ok,
     conn:
       conn
       |> put_req_header("x-semaphore-user-id", context[:user].id)
       |> put_req_header("x-semaphore-org-id", context[:organization].id)}

    setup_permissions(context, ["organization.view" | permissions])
  end

  defp setup_params(context) do
    {:ok,
     org_params: %{
       "role" => %{
         "description" => "Custom organization role description",
         "name" => "Another organization role name",
         "permissions" =>
           context.org_permissions
           |> Enum.with_index()
           |> Enum.into(%{}, fn {permission, index} ->
             {to_string(index), %{"granted" => "false", "name" => permission}}
           end),
         "scope" => "organization",
         "role_mapping" => "true",
         "maps_to" => context.role.id
       }
     },
     project_params: %{
       "role" => %{
         "description" => "Custom project role description",
         "name" => "Another project role name",
         "permissions" =>
           context.project_permissions
           |> Enum.with_index()
           |> Enum.into(%{}, fn {permission, index} ->
             {to_string(index), %{"granted" => "false", "name" => permission}}
           end),
         "scope" => "project"
       }
     }}
  end

  defp disable_feature(context) do
    Support.Stubs.Feature.disable_feature(context.organization_id, @feature_name)

    on_exit(fn ->
      Support.Stubs.Feature.enable_feature(context.organization_id, @feature_name)
    end)
  end

  defp zero_feature(context) do
    Support.Stubs.Feature.zero_feature(context.organization_id, @feature_name)

    on_exit(fn ->
      Support.Stubs.Feature.enable_feature(context.organization_id, @feature_name)
    end)
  end

  defp permission_selected?(html, permission_name) do
    regex = ~r{<label class="ml1" for="([a-z_0-9]+)">#{permission_name}</label>}
    assert [_pattern, checkbox_id] = Regex.run(regex, html)

    html =~ "<input checked id=\"#{checkbox_id}\"" or
      html =~ "<input checked disabled id=\"#{checkbox_id}\""
  end

  defp edit_button_visible?(html, role_id),
    do: index_button_visible?(html, "/roles/#{role_id}/edit", "edit")

  defp show_button_visible?(html, role_id),
    do: index_button_visible?(html, "/roles/#{role_id}", "visibility")

  defp index_button_visible?(html, path, icon) do
    button_class = "material-symbols-outlined f5 b btn pointer pa1 btn-secondary ml3"
    html =~ "<a class=\"#{button_class}\" href=\"#{path}\">#{icon}</a>"
  end

  defp role_mapping_unset?(html) do
    html =~ "input id=\"role_role_mapping\"" and
      not (html =~ "input checked id=\"role_role_mapping\"")
  end

  defp role_mapping_set?(html, role \\ nil) do
    (html =~ "input checked id=\"role_role_mapping\"" or
       html =~ "input checked disabled id=\"role_role_mapping\"") and
      html =~ "<option selected value=\"#{role.id}\">#{role.name}</option>"
  end

  defp grant_permissions_in_params(params, permission_names) do
    all_permissions = get_in(params, ["role", "permissions"])

    granted_permissions =
      all_permissions
      |> Enum.filter(fn {_key, value} ->
        value["name"] in permission_names
      end)
      |> Enum.into(%{}, fn {key, value} ->
        {key, Map.put(value, "granted", "true")}
      end)

    put_in(params, ["role", "permissions"], Map.merge(all_permissions, granted_permissions))
  end
end
