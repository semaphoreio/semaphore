defmodule FrontWeb.ProjectPFCControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.PermissionPatrol
  alias Support.Stubs.PreFlightChecks
  @moduletag :pre_flight_checks

  describe "GET /project/:project/pre_flight_checks" do
    setup [:setup_context, :setup_model, :setup_params, :authorize]

    test "denies access for unauthorized requests",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything_except(
        context.organization_id,
        context.user_id,
        "project.pre_flight_checks.view"
      )

      assert html = html_response(call_show(conn, project_id), 200)
      html =~ "Sorry, you can’t access Pre-flight checks."
    end

    test "allows access for authorized requests",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything_except(
        context.organization_id,
        context.user_id,
        "project.pre_flight_checks.manage"
      )

      html = html_response(call_show(conn, project_id), 200)
      assert html =~ "Pre-flight checks"
    end

    test "renders pre-flight checks if configured",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything_except(
        context.organization_id,
        context.user_id,
        "project.pre_flight_checks.manage"
      )

      html = html_response(call_show(conn, project_id), 200)
      assert html =~ "npm run-script custom_security_check -- --some-option some-value"
      assert html =~ "SECRET_TAG_3"
    end

    test "renders save button for authorized requests",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      html = html_response(call_show(conn, project_id), 200)
      assert html =~ "Save changes"
    end

    test "renders delete button for authorized requests",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      html = html_response(call_show(conn, project_id), 200)
      assert html =~ "Delete pre-flight checks"
    end

    test "does not render save button for unauthorized requests",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything_except(
        context.organization_id,
        context.user_id,
        "project.pre_flight_checks.manage"
      )

      html = html_response(call_show(conn, project_id), 200)
      refute html =~ "Save changes"
    end

    test "does not render delete button for unauthorized requests",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything_except(
        context.organization_id,
        context.user_id,
        "project.pre_flight_checks.manage"
      )

      html = html_response(call_show(conn, project_id), 200)
      refute html =~ "Delete pre-flight checks"
    end
  end

  describe "PUT /project/:project/pre_flight_checks" do
    setup [:setup_context, :setup_params, :authorize]

    test "denies access for unauthorized requests",
         %{conn: conn, project_id: project_id, params: params} = context do
      PermissionPatrol.allow_everything_except(
        context.organization_id,
        context.user_id,
        "project.pre_flight_checks.manage"
      )

      assert html_response(call_put(conn, project_id, params), 404)
    end

    test "allows access for authorized requests",
         %{conn: conn, project_id: project_id, params: params} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      assert redirected_to(call_put(conn, project_id, params)) =~
               pfc_path(conn, project_id, :show)
    end

    test "renders updated pre-flight check for correct params",
         %{conn: conn, project_id: project_id, params: params} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      assert conn = call_put(conn, project_id, params)
      assert redirected_to(conn, 302) =~ pfc_path(conn, project_id, :show)
      assert get_flash(conn, :notice) =~ "Success: pre-flight checks configured"

      assert html = html_response(call_show(recycle(conn), project_id), 200)
      assert html =~ "Pre-flight checks"

      assert html =~ "mix custom_security_check --some-option some-value"
      assert html =~ "SECRET_TAG_1"
    end

    test "renders form with errors for empty commands",
         %{conn: conn, project_id: project_id, params: params} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      params = Map.update!(params, "project_pfc", &Map.put(&1, "commands", ""))

      assert conn = call_put(conn, project_id, params)
      assert get_flash(conn, :alert) =~ "Failure: provided invalid data"
      assert html = html_response(conn, 200)
      assert html =~ "Pre-flight checks"
      assert html =~ "should have at least 1 item(s)"
    end

    test "renders form with errors for empty agent machine_type",
         %{conn: conn, project_id: project_id, params: params} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      params =
        params
        |> Map.update!("project_pfc", fn pfc ->
          Map.update!(pfc, "agent", &Map.put(&1, "machine_type", ""))
        end)

      assert conn = call_put(conn, project_id, params)
      assert get_flash(conn, :alert) =~ "Failure: provided invalid data"
      assert html = html_response(conn, 200)
      assert html =~ "Pre-flight checks"
      assert html =~ "can&#39;t be blank"
    end

    test "renders updated pre-flight check for empty agent os_image",
         %{conn: conn, project_id: project_id, params: params} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      params =
        params
        |> Map.update!("project_pfc", fn pfc ->
          Map.update!(pfc, "agent", &Map.put(&1, "os_image", ""))
        end)

      assert conn = call_put(conn, project_id, params)
      assert redirected_to(conn, 302) =~ pfc_path(conn, project_id, :show)
      assert get_flash(conn, :notice) =~ "Success: pre-flight checks configured"

      assert html = html_response(call_show(recycle(conn), project_id), 200)
      assert html =~ "Pre-flight checks"

      assert html =~ "mix custom_security_check --some-option some-value"
      assert html =~ "SECRET_TAG_1"
    end

    test "renders updated pre-flight check for falsey has_custom_agent",
         %{conn: conn, project_id: project_id, params: params} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      params =
        params
        |> Map.update!("project_pfc", fn pfc ->
          Map.put(pfc, "has_custom_agent", "false")
        end)

      assert conn = call_put(conn, project_id, params)
      assert redirected_to(conn, 302) =~ pfc_path(conn, project_id, :show)
      assert get_flash(conn, :notice) =~ "Success: pre-flight checks configured"

      assert html = html_response(call_show(recycle(conn), project_id), 200)
      assert html =~ "Pre-flight checks"

      assert html =~ "mix custom_security_check --some-option some-value"
      assert html =~ "SECRET_TAG_1"
    end
  end

  describe "DELETE /project/:project/pre_flight_checks" do
    setup [:setup_context, :setup_model, :authorize]

    test "denies access for unauthorized requests",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything_except(
        context.organization_id,
        context.user_id,
        "project.pre_flight_checks.manage"
      )

      assert html_response(call_delete(conn, project_id), 404)
    end

    test "allows access for authorized requests",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      assert redirected_to(call_delete(conn, project_id)) =~ pfc_path(conn, project_id, :show)
    end

    test "renders empty form after deleting pre-flight checks",
         %{conn: conn, project_id: project_id} = context do
      PermissionPatrol.allow_everything(context.organization_id, context.user_id)

      assert conn = call_delete(conn, project_id)
      assert redirected_to(conn, 302) =~ pfc_path(conn, project_id, :show)
      assert get_flash(conn, :notice) =~ "Success: pre-flight checks deleted"

      assert html = html_response(call_show(recycle(conn), project_id), 200)
      assert html =~ "Pre-flight checks"
    end
  end

  defp call_show(conn, project_id), do: get(conn, pfc_path(conn, project_id, :show))
  defp call_put(conn, project_id, params), do: put(conn, pfc_path(conn, project_id, :put), params)
  defp call_delete(conn, project_id), do: delete(conn, pfc_path(conn, project_id, :delete))

  defp pfc_path(conn, project_id, method), do: project_pfc_path(conn, method, project_id)

  defp setup_context(_context) do
    Cacheman.clear(:front)
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    Support.Stubs.PermissionPatrol.remove_all_permissions()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()
    project = Support.Stubs.DB.first(:projects)

    Support.Stubs.Feature.enable_feature(organization.id, :pre_flight_checks)

    System.put_env("FEATURES_PRE_FLIGHT_CHECKS_ORG_IDS", organization.id)

    {:ok,
     [
       organization_id: organization.id,
       user_id: user.id,
       project_id: project.id
     ]}
  end

  defp authorize(context = %{conn: conn}) do
    {:ok,
     conn:
       conn
       |> put_req_header("x-semaphore-user-id", context[:user_id])
       |> put_req_header("x-semaphore-org-id", context[:organization_id])}
  end

  defp setup_params(_context) do
    {:ok,
     params: %{
       "project_pfc" => %{
         "commands" =>
           [
             "checkout",
             "mix local.hex --force && local.rebar --force",
             "mix deps.get && mix.compile",
             "mix custom_security_check --some-option some-value"
           ]
           |> Enum.join("\n"),
         "secrets" => [
           "SECRET_TAG_1",
           "SECRET_TAG_2"
         ],
         "has_custom_agent" => "true",
         "agent" => %{
           "machine_type" => "e1-standard-2",
           "os_image" => "ubuntu1804"
         }
       }
     }}
  end

  defp setup_model(context) do
    PreFlightChecks.create(:project_pfc, context[:project_id], %{
      commands: [
        "checkout",
        "npm install",
        "npm run-script custom_security_check -- --some-option some-value"
      ],
      secrets: [
        "SECRET_TAG_3",
        "SECRET_TAG_4"
      ],
      agent: %{
        machine_type: "a1-standard-4",
        os_image: "macos-xcode13"
      }
    }) && :ok
  end
end
