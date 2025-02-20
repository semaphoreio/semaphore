defmodule FrontWeb.OrganizationPFCControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.PreFlightChecks
  @moduletag :pre_flight_checks

  describe "GET /pre_flight_checks or /init_job_settings" do
    setup [:setup_context, :setup_model, :setup_params, :authorize]

    test "denies access for unauthorized requests", %{conn: conn} do
      assert html_response(call_show(conn), 404)
    end

    test "allows access for authorized requests", %{conn: conn} = context do
      setup_permissions(context, ["organization.view", "organization.pre_flight_checks.view"])

      html = html_response(call_show(conn), 200)
      assert html =~ "Pre-flight checks"
    end

    test "renders pre-flight checks if configured", %{conn: conn} = context do
      setup_permissions(context, ["organization.view", "organization.pre_flight_checks.view"])

      html = html_response(call_show(conn), 200)
      assert html =~ "npm run-script custom_security_check -- --some-option some-value"
      assert html =~ "SECRET_TAG_3"
    end

    test "renders save button for authorized requests", %{conn: conn} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      html = html_response(call_show(conn), 200)
      assert html =~ "Save changes"
    end

    test "renders delete button for authorized requests", %{conn: conn} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      html = html_response(call_show(conn), 200)
      assert html =~ "Delete pre-flight checks"
    end

    test "does not render save button for unauthorized requests", %{conn: conn} = context do
      setup_permissions(context, ["organization.view", "organization.pre_flight_checks.view"])

      html = html_response(call_show(conn), 200)
      refute html =~ "Save changes"
    end

    test "does not render delete button for unauthorized requests", %{conn: conn} = context do
      setup_permissions(context, ["organization.view", "organization.pre_flight_checks.view"])

      html = html_response(call_show(conn), 200)
      refute html =~ "Delete pre-flight checks"
    end
  end

  describe "PUT /pre_flight_checks" do
    setup [:setup_context, :setup_params, :authorize]

    test "denies access for unauthorized requests, redirect to pfc",
         %{conn: conn, params: params} = context do
      setup_permissions(context, ["organization.view", "organization.pre_flight_checks.view"])

      assert html_response(call_put_pfcs(conn, params), 302)
    end

    test "allows access for authorized requests", %{conn: conn, params: params} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      assert redirected_to(call_put_pfcs(conn, params)) =~ pfc_path(conn, :show)
    end

    test "renders updated pre-flight check for correct params",
         %{conn: conn, params: params} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      assert conn = call_put_pfcs(conn, params)
      assert redirected_to(conn, 302) =~ pfc_path(conn, :show)
      assert get_flash(conn, :notice) =~ "Success: pre-flight checks configured"

      assert html = html_response(call_show(recycle(conn)), 200)
      assert html =~ "Pre-flight checks"

      assert html =~ "mix custom_security_check --some-option some-value"
      assert html =~ "SECRET_TAG_1"
    end

    test "renders form with errors for empty commands", %{conn: conn, params: params} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      params = Map.update!(params, "organization_pfc", &Map.put(&1, "commands", ""))

      assert conn = call_put_pfcs(conn, params)
      assert get_flash(conn, :alert) =~ "Failure: provided invalid data"
      assert html = html_response(conn, 200)
      assert html =~ "Pre-flight checks"
      assert html =~ "should have at least 1 item(s)"
    end
  end

  describe "PUT /init_job_settings" do
    setup [:setup_context, :setup_params, :authorize]

    test "denies access for unauthorized requests, redirect to pfc",
         %{conn: conn, params: params} = context do
      setup_permissions(context, ["organization.view", "organization.pre_flight_checks.view"])

      assert html_response(call_put_ijd(conn, params), 302)
      assert redirected_to(call_put_ijd(conn, params)) =~ pfc_path(conn, :show)
    end

    test "allows access for authorized requests", %{conn: conn, params: params} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      assert redirected_to(call_put_ijd(conn, params)) =~ pfc_path(conn, :show)
    end

    test "renders updated init job settings for correct params",
         %{conn: conn, params: params} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      assert conn = call_put_ijd(conn, params)
      assert redirected_to(conn, 302) =~ pfc_path(conn, :show)
      assert get_flash(conn, :notice) =~ "Success: initialization job settings configured"

      assert html = html_response(call_show(recycle(conn)), 200)
      assert html =~ "Agent configuration"

      assert html =~ "e1-standard-2"
      assert html =~ "ubuntu1804"
    end

    test "renders form with errors for empty machine type",
         %{conn: conn, params: params} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      params = Map.update!(params, "agent_config", &Map.put(&1, "machine_type", ""))

      assert conn = call_put_ijd(conn, params)
      assert redirected_to(conn, 302) =~ pfc_path(conn, :show)
      assert get_flash(conn, :alert) =~ "Failure: provided invalid data"
    end
  end

  describe "DELETE /pre_flight_checks" do
    setup [:setup_context, :setup_model, :authorize]

    test "denies access for unauthorized requests, redirect to pfc", %{conn: conn} = context do
      setup_permissions(context, ["organization.view", "organization.pre_flight_checks.view"])

      assert html_response(call_delete(conn), 302)
    end

    test "allows access for authorized requests", %{conn: conn} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      assert redirected_to(call_delete(conn)) =~ pfc_path(conn, :show)
    end

    test "renders empty form after deleting pre-flight checks",
         %{conn: conn} = context do
      setup_permissions(context, [
        "organization.view",
        "organization.pre_flight_checks.view",
        "organization.pre_flight_checks.manage"
      ])

      assert conn = call_delete(conn)
      assert redirected_to(conn, 302) =~ pfc_path(conn, :show)
      assert get_flash(conn, :notice) =~ "Success: pre-flight checks deleted"

      assert html = html_response(call_show(recycle(conn)), 200)
      assert html =~ "Pre-flight checks"
    end
  end

  defp call_show(conn), do: get(conn, pfc_path(conn, :show))
  defp call_put_ijd(conn, params), do: put(conn, pfc_path(conn, :put_init_job_defaults), params)
  defp call_put_pfcs(conn, params), do: put(conn, pfc_path(conn, :put_pre_flight_checks), params)
  defp call_delete(conn), do: delete(conn, pfc_path(conn, :delete))

  defp pfc_path(conn, method), do: organization_pfc_path(conn, method)

  defp setup_context(_context) do
    Cacheman.clear(:front)
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    Support.Stubs.PermissionPatrol.remove_all_permissions()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()

    Support.Stubs.Feature.enable_feature(organization.id, :pre_flight_checks)

    System.put_env("FEATURES_PRE_FLIGHT_CHECKS_ORG_IDS", organization.id)

    {:ok,
     [
       organization: organization,
       organization_id: organization.id,
       user: user,
       user_id: user.id
     ]}
  end

  defp setup_permissions(context, permissions) do
    Support.Stubs.PermissionPatrol.add_permissions(
      context.organization_id,
      context.user_id,
      permissions
    )
  end

  defp authorize(context = %{conn: conn}) do
    {:ok,
     conn:
       conn
       |> put_req_header("x-semaphore-user-id", context[:user].id)
       |> put_req_header("x-semaphore-org-id", context[:organization].id)}
  end

  defp setup_params(_context) do
    {:ok,
     params: %{
       "organization_pfc" => %{
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
         ]
       },
       "agent_config" => %{
         "machine_type" => "e1-standard-2",
         "os_image" => "ubuntu1804"
       }
     }}
  end

  defp setup_model(context) do
    PreFlightChecks.create(:organization_pfc, context[:organization_id], %{
      commands: [
        "checkout",
        "npm install",
        "npm run-script custom_security_check -- --some-option some-value"
      ],
      secrets: [
        "SECRET_TAG_3",
        "SECRET_TAG_4"
      ]
    }) && :ok
  end
end
