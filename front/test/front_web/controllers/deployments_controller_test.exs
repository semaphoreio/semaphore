defmodule FrontWeb.DeploymentsControllerTest do
  use FrontWeb.ConnCase
  @moduletag capture_log: true
  @moduletag :deployments

  alias Support.Stubs.{DB, Deployments, PermissionPatrol}

  setup [:setup_context, :enable_feature, :setup_model, :setup_params, :authorize]

  describe "GET /project/:project/deployments/" do
    test "denies access for unauthorized organizations",
         %{conn: conn, project_id: project_id} = context do
      disable_feature(context)
      on_exit(fn -> enable_feature(context) end)

      assert html_response(call_index(conn, project_id), 404)
    end

    test "denies access for unauthorized users",
         %{conn: conn, project_id: project_id, organization_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.deployment_targets.view")
      assert html = html_response(call_index(conn, project_id), 200)
      assert html =~ "Sorry, you can’t access Deployment Targets."
    end

    test "allows access for authorized requests",
         %{conn: conn, project_id: project_id, organization_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      html = html_response(call_index(conn, project_id), 200)
      assert html =~ "Deployment targets"
    end

    test "renders deployment targets if configured",
         %{conn: conn, project_id: project_id, organization_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      html = html_response(call_index(conn, project_id), 200)

      assert html =~ "Deployment targets"
      assert html =~ ~s(<p class="mb0 b ml1">Staging</p>)
    end

    test "renders create button for authorized requests",
         %{conn: conn, project_id: project_id} do
      html = html_response(call_index(conn, project_id), 200)
      assert html =~ "Create New</a>"
    end

    test "renders edit buttons for authorized requests",
         %{conn: conn, project_id: project_id} do
      html = html_response(call_index(conn, project_id), 200)
      assert html =~ "Edit</a>"
    end

    test "renders delete buttons for authorized requests",
         %{conn: conn, project_id: project_id} do
      html = html_response(call_index(conn, project_id), 200)
      assert html =~ "Delete</a>"
    end

    test "does not render create button for unauthorized users",
         %{conn: conn, project_id: project_id, organization_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      html = html_response(call_index(conn, project_id), 200)
      refute html =~ "Create New</a>"
    end

    test "does not render edit buttons for unauthorized users",
         %{conn: conn, project_id: project_id, organization_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      html = html_response(call_index(conn, project_id), 200)
      refute html =~ "Edit</a>"
    end

    test "does not render delete buttons for unauthorized users",
         %{conn: conn, project_id: project_id, organization_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      html = html_response(call_index(conn, project_id), 200)
      refute html =~ "Delete</a>"
    end
  end

  describe "GET /project/:project/deployments/new" do
    test "denies access for unauthorized organizations",
         %{conn: conn, project_id: project_id} = context do
      disable_feature(context)
      on_exit(fn -> enable_feature(context) end)

      assert html_response(call_new(conn, project_id), 404)
    end

    test "denies access for unauthorized users",
         %{conn: conn, project_id: project_id, organization_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      assert html = html_response(call_new(conn, project_id), 200)
      assert html =~ "Sorry, you can’t modify Deployment Targets."
    end

    test "grants access with manage permissions",
         %{conn: conn, project_id: project_id} do
      html = html_response(call_new(conn, project_id), 200)
      assert html =~ "New Deployment Target"
    end

    test "renders deployment target create wizard",
         %{conn: conn, project_id: project_id} do
      html = html_response(call_new(conn, project_id), 200)

      assert html =~ "New Deployment Target"
      assert html =~ "Provide information that will allow your team"
    end
  end

  describe "GET /project/:project/deployments/:id" do
    test "denies access for unauthorized organizations",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      disable_feature(context)
      on_exit(fn -> enable_feature(context) end)

      assert html_response(call_show(conn, project_id, target_id), 404)
    end

    test "denies access if project doesn't match target",
         %{
           conn: conn,
           target_id: target_id,
           other_project_id: other_project_id
         } do
      assert html_response(call_show(conn, other_project_id, target_id), 404)
    end

    test "denies access for unauthorized users",
         %{
           conn: conn,
           project_id: project_id,
           target_id: target_id,
           organization_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.deployment_targets.view")
      assert html = html_response(call_show(conn, project_id, target_id), 200)
      assert html =~ "Sorry, you can’t access Deployment Targets."
    end

    test "grants access with view permissions",
         %{
           conn: conn,
           project_id: project_id,
           target_id: target_id,
           organization_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      html = html_response(call_show(conn, project_id, target_id), 200)
      assert html =~ "Deployment History"
    end

    test "renders 404 when target was not found",
         %{conn: conn, project_id: project_id, organization_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      assert html_response(call_show(conn, project_id, UUID.uuid4()), 404)
    end

    test "renders deployment target data",
         %{
           conn: conn,
           project_id: project_id,
           target_id: target_id,
           organization_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      html = html_response(call_show(conn, project_id, target_id), 200)

      assert html =~ "Deployment History"
      assert html =~ "Staging environment"
      assert html =~ "https://staging.example.com"
      assert html =~ "We didn't find any deployments matching your criteria."
    end

    test "renders deployment target history",
         %{
           conn: conn,
           project_id: project_id,
           target_id: target_id,
           organization_id: org_id,
           user_id: user_id
         } = context do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      setup_deployment(context)

      html = html_response(call_show(conn, project_id, target_id), 200)

      assert html =~ "Deployment History"
      assert html =~ "Staging environment"
      assert html =~ "https://staging.example.com"

      refute html =~ "Deployment History is empty."
      assert html =~ "Deploy to Staging"
    end
  end

  describe "GET /project/:project/deployments/:id/edit" do
    test "denies access for unauthorized organizations",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      disable_feature(context)
      on_exit(fn -> enable_feature(context) end)

      assert html_response(call_edit(conn, project_id, target_id), 404)
    end

    test "denies access if project doesn't match target",
         %{
           conn: conn,
           target_id: target_id,
           other_project_id: other_project_id
         } do
      assert html_response(call_edit(conn, other_project_id, target_id), 404)
    end

    test "denies access for unauthorized users",
         %{
           conn: conn,
           project_id: project_id,
           target_id: target_id,
           organization_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      assert html = html_response(call_edit(conn, project_id, target_id), 200)
      assert html =~ "Sorry, you can’t modify Deployment Targets."
    end

    test "renders 404 when target was not found",
         %{conn: conn, project_id: project_id} do
      assert html_response(call_edit(conn, project_id, UUID.uuid4()), 404)
    end

    test "grants access with manage permissions",
         %{conn: conn, project_id: project_id, target_id: target_id} do
      html = html_response(call_edit(conn, project_id, target_id), 200)
      assert html =~ "Edit Deployment Target"
    end

    test "renders deployment target edit page",
         %{conn: conn, project_id: project_id, target_id: target_id} do
      html = html_response(call_edit(conn, project_id, target_id), 200)

      assert html =~ "Edit Deployment Target"
      assert html =~ ~s(<input name="_method" type="hidden" value="put">)
      assert html =~ "Use alphabetic characters, numbers, underscores and dashes"
      refute html =~ "Provide information that will allow your team"
    end

    test "renders deployment target data",
         %{conn: conn, project_id: project_id, target_id: target_id} do
      html = html_response(call_edit(conn, project_id, target_id), 200)

      assert html =~ "Edit Deployment Target"
      assert html =~ ~s(value="Staging")
      assert html =~ "Staging environment"
    end
  end

  describe "PUT /project/:project/deployments/:id/cordon/:state" do
    test "denies access for unauthorized organizations",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      disable_feature(context)
      on_exit(fn -> enable_feature(context) end)

      assert html_response(call_cordon(conn, project_id, target_id, "on"), 404)
    end

    test "denies access if project doesn't match target",
         %{
           conn: conn,
           target_id: target_id,
           other_project_id: other_project_id
         } do
      assert html_response(call_cordon(conn, other_project_id, target_id, "on"), 404)
    end

    test "denies access for unauthorized users",
         %{
           conn: conn,
           project_id: project_id,
           target_id: target_id,
           organization_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      assert html_response(call_cordon(conn, project_id, target_id, "on"), 404)
    end

    test "returns 404 when target was not found",
         %{conn: conn, project_id: project_id} = _context do
      assert html_response(call_cordon(conn, project_id, UUID.uuid4(), "on"), 404)
    end

    test "renders 404 when state is not `on` or `off`",
         %{conn: conn, project_id: project_id} = _context do
      assert html_response(call_cordon(conn, project_id, UUID.uuid4(), "test"), 404)
    end

    test "grants access for authorized requests",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      assert redirected_to(call_cordon(conn, project_id, target_id, "on")) =~
               dt_path(conn, context.project.name, :index)
    end

    test "renders list of deployment targets with activate link",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      assert conn = call_cordon(conn, project_id, target_id, "on")
      assert redirected_to(conn, 302) =~ dt_path(conn, context.project.name, :index)
      assert get_flash(conn, :notice) =~ "Success: deployment target has been blocked"

      assert html = html_response(call_index(recycle(conn), project_id), 200)
      assert html =~ "Deployment Targets"
      assert html =~ "Inactive"
      assert html =~ "Activate"
    end

    test "renders deployment history with deactiveate link",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      target = %{target | api_model: %{target.api_model | cordoned: true}}
      Support.Stubs.DB.upsert(:deployment_targets, target)

      assert conn = call_cordon(conn, project_id, target_id, "off")
      assert redirected_to(conn, 302) =~ dt_path(conn, context.project.name, :index)
      assert get_flash(conn, :notice) =~ "Success: deployment target has been unblocked"

      assert html = html_response(call_index(recycle(conn), project_id), 200)
      assert html =~ "Deployment Targets"
      assert html =~ "Active"
      assert html =~ "Deactivate"
    end

    test "renders form again when internal error occurs",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      Deployments.Grpc.expect(:cordon, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unknown error"
      end)

      assert conn = call_cordon(conn, project_id, target_id, "on")
      assert redirected_to(conn, 302) =~ dt_path(conn, context.project.name, :index)
      assert get_flash(conn, :alert) =~ "Failure: unable to block Deployment Target"

      assert html = html_response(call_show(recycle(conn), project_id, target_id), 200)
      assert html =~ "Deployment History"
    end
  end

  describe "POST /project/:project/deployments/" do
    test "denies access for unauthorized organizations",
         %{conn: conn, project_id: project_id, params: params} = context do
      disable_feature(context)
      on_exit(fn -> enable_feature(context) end)

      assert html_response(call_create(conn, project_id, params), 404)
    end

    test "denies access for unauthorized users",
         %{
           conn: conn,
           project_id: project_id,
           params: params,
           organization_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      assert html_response(call_create(conn, project_id, params), 404)
    end

    test "grants access for authorized requests",
         %{conn: conn, project_id: project_id, params: params} = context do
      assert redirected_to(call_create(conn, project_id, params)) =~
               dt_path(conn, context.project.name, :index)
    end

    test "renders updated list of deployment targets",
         %{conn: conn, project_id: project_id, params: params} = context do
      assert conn = call_create(conn, project_id, params)
      assert redirected_to(conn, 302) =~ dt_path(conn, context.project.name, :index)
      assert get_flash(conn, :notice) =~ "Success: deployment target created"

      assert html = html_response(call_index(recycle(conn), project_id), 200)
      assert html =~ "Deployment targets"
      assert html =~ ~s(<p class="mb0 b ml1">Production</p>)
    end

    test "renders form again for invalid arguments",
         %{conn: conn, project_id: project_id, params: params} do
      params = Map.put(params, "name", "")
      assert conn = call_create(conn, project_id, params)
      assert get_flash(conn, :alert) =~ "Failure: provided invalid data"

      assert html = html_response(conn, 200)
      assert html =~ "New Deployment Target"
      assert html =~ "Production environment"
    end

    test "renders form again for internal error",
         %{conn: conn, project_id: project_id, params: params} do
      Deployments.Grpc.expect(:create, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unknown error"
      end)

      assert conn = call_create(conn, project_id, params)
      assert get_flash(conn, :alert) =~ "Failure: unable to create target"

      assert html = html_response(conn, 200)
      assert html =~ "New Deployment Target"
      assert html =~ "Production environment"
    end
  end

  describe "PUT /project/:project/deployments/:id" do
    test "denies access for unauthorized organizations",
         %{conn: conn, project_id: project_id, target_id: target_id, params: params} = context do
      disable_feature(context)
      on_exit(fn -> enable_feature(context) end)

      assert html_response(call_update(conn, project_id, target_id, params), 404)
    end

    test "denies access if project doesn't match target",
         %{
           conn: conn,
           target_id: target_id,
           other_project_id: other_project_id,
           params: params
         } do
      assert html_response(call_update(conn, other_project_id, target_id, params), 404)
    end

    test "denies access for unauthorized users",
         %{
           conn: conn,
           project_id: project_id,
           target_id: target_id,
           params: params,
           organization_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      assert html_response(call_update(conn, project_id, target_id, params), 404)
    end

    test "renders 404 when target was not found",
         %{conn: conn, project_id: project_id, params: params} do
      assert html_response(call_update(conn, project_id, UUID.uuid4(), params), 404)
    end

    test "grants access for authorized requests",
         %{conn: conn, project_id: project_id, target_id: target_id, params: params} = context do
      assert redirected_to(call_update(conn, project_id, target_id, params)) =~
               dt_path(conn, context.project.name, :index)
    end

    test "renders updated list of deployment targets",
         %{conn: conn, project_id: project_id, target_id: target_id, params: params} = context do
      assert conn = call_update(conn, project_id, target_id, params)
      assert redirected_to(conn, 302) =~ dt_path(conn, context.project.name, :index)
      assert get_flash(conn, :notice) =~ "Success: deployment target updated"

      assert html = html_response(call_index(recycle(conn), project_id), 200)
      assert html =~ "Deployment Targets"
      assert html =~ ~s(<p class="mb0 b ml1">Production</p>)
    end

    test "renders form again for invalid arguments",
         %{conn: conn, project_id: project_id, target_id: target_id, params: params} do
      params = Map.put(params, "name", "")
      assert conn = call_update(conn, project_id, target_id, params)
      assert get_flash(conn, :alert) =~ "Failure: provided invalid data"

      assert html = html_response(conn, 200)
      assert html =~ "Edit Deployment Target"
      assert html =~ "Production"
      refute html =~ "Staging"
    end

    test "renders form again when internal error occurs",
         %{conn: conn, project_id: project_id, target_id: target_id, params: params} do
      Deployments.Grpc.expect(:update, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unknown error"
      end)

      assert conn = call_update(conn, project_id, target_id, params)
      assert get_flash(conn, :alert) =~ "Failure: unable to update target"

      assert html = html_response(conn, 200)
      assert html =~ "Edit Deployment Target"
      assert html =~ "Production"
      refute html =~ "Staging"
    end
  end

  describe "DELETE /project/:project/deployments/:id" do
    test "denies access for unauthorized organizations",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      disable_feature(context)
      on_exit(fn -> enable_feature(context) end)

      assert html_response(call_delete(conn, project_id, target_id), 404)
    end

    test "denies access if project doesn't match target",
         %{
           conn: conn,
           target_id: target_id,
           other_project_id: other_project_id
         } do
      assert html_response(call_delete(conn, other_project_id, target_id), 404)
    end

    test "denies access for unauthorized users",
         %{
           conn: conn,
           project_id: project_id,
           target_id: target_id,
           organization_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        org_id,
        user_id,
        "project.deployment_targets.manage"
      )

      assert html_response(call_delete(conn, project_id, target_id), 404)
    end

    test "allows access for authorized requests",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      assert redirected_to(call_delete(conn, project_id, target_id)) =~
               dt_path(conn, context.project.name, :index)
    end

    test "renders main page without target after deleting it",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      assert conn = call_delete(conn, project_id, target_id)
      assert redirected_to(conn, 302) =~ dt_path(conn, context.project.name, :index)
      assert get_flash(conn, :notice) =~ "Success: deployment target deleted"

      assert html = html_response(call_index(recycle(conn), project_id), 200)
      assert html =~ "Deployment targets"
      refute html =~ ~s(<p class="mb0 b ml1">Staging</p>)
      refute html =~ ~s(<p class="mb0 b ml1">Production</p>)
    end

    test "renders main page with flash when internal error occurs",
         %{conn: conn, project_id: project_id, target_id: target_id} = context do
      Deployments.Grpc.expect(:delete, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unknown error"
      end)

      assert conn = call_delete(conn, project_id, target_id)
      assert redirected_to(conn, 302) =~ dt_path(conn, context.project.name, :index)
      assert get_flash(conn, :alert) =~ "Failure: unable to delete target"

      assert html = html_response(call_index(recycle(conn), project_id), 200)
      assert html =~ "Deployment targets"
      assert html =~ ~s(<p class="mb0 b ml1">Staging</p>)
      refute html =~ ~s(<p class="mb0 b ml1">Production</p>)
    end
  end

  describe "preprocess_params/1" do
    setup do
      {:ok, conn: %{assigns: %{organization_id: Support.Stubs.Organization.default_org_id()}}}
    end

    test "when organization doesn't have advanced feature then puts any user access", ctx do
      Support.Stubs.Feature.disable_feature(
        ctx.conn.assigns.organization_id,
        :advanced_deployment_targets
      )

      on_exit(fn ->
        Support.Stubs.Feature.enable_feature(
          ctx.conn.assigns.organization_id,
          :advanced_deployment_targets
        )
      end)

      assert result = FrontWeb.DeploymentsController.preprocess_params(ctx.conn, %{})
      assert "any" == result["user_access"]
    end

    test "when collection params are missing then puts empty lists", ctx do
      assert result = FrontWeb.DeploymentsController.preprocess_params(ctx.conn, %{})

      for collection_name <- ~w(env_vars files roles members branches tags) do
        assert collection = Map.get(result, collection_name)
        assert Enum.empty?(collection)
      end
    end

    test "when collection contains empty elements then rejects them", ctx do
      assert %{
               "env_vars" => [%{"id" => "", "name" => "name", "value" => "value"}],
               "files" => [%{"id" => "", "path" => "path", "content" => "content"}],
               "branches" => [%{"match_mode" => "1", "pattern" => "master"}],
               "tags" => [%{"match_mode" => "1", "pattern" => "latest"}]
             } =
               FrontWeb.DeploymentsController.preprocess_params(ctx.conn, %{
                 "env_vars" => %{
                   "0" => %{"id" => "", "name" => "", "value" => ""},
                   "1" => %{"id" => "", "name" => "name", "value" => "value"}
                 },
                 "files" => %{
                   "0" => %{"id" => "", "path" => "", "content" => ""},
                   "1" => %{"id" => "", "path" => "path", "content" => "content"}
                 },
                 "branches" => %{
                   "0" => %{"match_mode" => "", "pattern" => ""},
                   "1" => %{"match_mode" => "1", "pattern" => "master"}
                 },
                 "tags" => %{
                   "0" => %{"match_mode" => "", "pattern" => ""},
                   "1" => %{"match_mode" => "1", "pattern" => "latest"}
                 }
               })
    end
  end

  defp call_index(conn, project_id),
    do: get(conn, dt_path(conn, project_id, :index))

  defp call_new(conn, project_id),
    do: get(conn, dt_path(conn, project_id, :new))

  defp call_show(conn, project_id, target_id),
    do: get(conn, dt_path(conn, project_id, target_id, :show))

  defp call_edit(conn, project_id, target_id),
    do: get(conn, dt_path(conn, project_id, target_id, :edit))

  defp call_cordon(conn, project_id, target_id, state),
    do: put(conn, dt_path(conn, :cordon, [project_id, target_id, state]))

  defp call_create(conn, project_id, params),
    do: post(conn, dt_path(conn, project_id, :create), %{"target" => params})

  defp call_update(conn, project_id, target_id, params),
    do: put(conn, dt_path(conn, project_id, target_id, :update), %{"target" => params})

  defp call_delete(conn, project_id, target_id),
    do: delete(conn, dt_path(conn, project_id, target_id, :delete))

  defp dt_path(conn, method, args) when is_list(args),
    do: Kernel.apply(FrontWeb.Router.Helpers, :deployments_path, [conn, method | args])

  defp dt_path(conn, project_id, method),
    do: deployments_path(conn, method, project_id)

  defp dt_path(conn, project_id, target_id, method),
    do: deployments_path(conn, method, project_id, target_id)

  defp enable_feature(ctx) do
    Support.Stubs.Feature.enable_feature(
      ctx.organization.id,
      :deployment_targets
    )

    :ok
  end

  defp disable_feature(ctx) do
    Support.Stubs.Feature.disable_feature(
      ctx.organization.id,
      :deployment_targets
    )

    :ok
  end

  defp authorize(context = %{conn: conn}) do
    {:ok,
     conn:
       conn
       |> put_req_header("x-semaphore-user-id", context.user.id)
       |> put_req_header("x-semaphore-org-id", context.organization.id)}
  end

  defp setup_context(_context) do
    Cacheman.clear(:front)
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    organization = DB.first(:organizations)
    project = DB.first(:projects)

    other_project =
      Support.Stubs.Project.create(organization, user, name: "test", run_on: ["branches"])

    PermissionPatrol.allow_everything(organization.id, user.id)

    ids = [
      organization_id: organization.id,
      user_id: user.id,
      project_id: project.id,
      other_project_id: other_project.id
    ]

    entities = [
      organization: organization,
      user: user,
      project: project,
      other_project: other_project
    ]

    {:ok, Keyword.merge(entities, ids)}
  end

  defp setup_model(context) do
    {target, _secret} =
      Deployments.create(context.project, context.user, "Staging", %{
        description: "Staging environment",
        url: "https://staging.example.com",
        env_vars: [%{name: "ENV_VAR", value: "VALUE"}],
        files: [%{path: "/home/path", content: "CONTENT"}]
      })

    {:ok, target_id: target.id}
  end

  defp setup_deployment(_context) do
    workflow = DB.first(:workflows)
    pipeline = DB.first(:pipelines)
    switch = DB.first(:switches)
    user = DB.first(:users)
    hook = DB.first(:hooks)

    deployment_target = DB.first(:deployment_targets)

    promotion_pipeline =
      Support.Stubs.Pipeline.create(workflow,
        name: "Deploy to #{deployment_target.name}",
        promotion_of: pipeline.id,
        commit_message: hook.api_model.commit_message
      )
      |> then(&Support.Stubs.Pipeline.change_state(&1.id, :passed))

    Support.Stubs.Deployments.add_deployment(deployment_target, user, switch, %{
      pipeline_id: promotion_pipeline && promotion_pipeline.id,
      state: :STARTED
    })

    on_exit(fn ->
      Support.Stubs.init()
      Support.Stubs.build_shared_factories()
    end)
  end

  defp setup_params(_ctx) do
    {:ok, params: Support.Factories.Deployments.prepare_params()}
  end
end
