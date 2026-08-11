# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.OrganizationOktaControllerTest do
  @moduledoc """
    Here we are testing access restrictions based on permissions.
    The rest of the okta related tests are performed inside other scripts
  """
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    Support.Stubs.PermissionPatrol.remove_all_permissions()

    user = DB.first(:users)
    user_id = Map.get(user, :id)

    organization = DB.first(:organizations)
    organization_id = Map.get(organization, :id)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    [
      conn: conn,
      organization_id: organization_id,
      user_id: user_id
    ]
  end

  describe "show" do
    test "returns 404 if user cant access organization", %{conn: conn} do
      conn =
        conn
        |> get(organization_okta_path(conn, :show))

      assert html_response(conn, 404)
    end

    test "If user can't view okta settings, show appropriate message", %{conn: conn} = ctx do
      add_permissions(ctx, ["organization.view"])

      conn =
        conn
        |> get(organization_okta_path(conn, :show))

      assert html_response(conn, 200) =~ "Sorry, you can’t access okta integration settings."
    end

    test "If user can view okta settings, but can't manage them", %{conn: conn} = ctx do
      add_permissions(ctx, ["organization.view", "organization.okta.view"])

      conn =
        conn
        |> get(organization_okta_path(conn, :show))

      html = html_response(conn, 200)
      assert html =~ "Single sign-on with SAML"
      # Set up button is disabled
      assert html =~ "disabled"
    end

    test "If user can view and manage okta settings", %{conn: conn} = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      conn =
        conn
        |> get(organization_okta_path(conn, :show))

      html = html_response(conn, 200)
      assert html =~ "Single sign-on with SAML"
      # No buttons are disabled
      refute html =~ "disabled"
    end

    test "If okta integration exists, show session expiration editor", %{conn: conn} = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      DB.insert(:okta_integrations, %{
        id: Ecto.UUID.generate(),
        org_id: ctx.organization_id,
        creator_id: ctx.user_id,
        sso_url: "https://example.okta.com",
        saml_issuer: "https://example.okta.com",
        saml_certificate: "test-certificate",
        jit_provisioning_enabled: true,
        session_expiration_minutes: session_expiration_days_to_minutes(1),
        created_at: Support.Stubs.Time.now(),
        updated_at: Support.Stubs.Time.now()
      })

      conn =
        conn
        |> get(organization_okta_path(conn, :show))

      html = html_response(conn, 200)
      assert html =~ "Session expiration"
      assert html =~ "session_expiration_days"
      assert html =~ "value=\"1\""
    end
  end

  describe "form" do
    test "If user can't manage okta, show 404", %{conn: conn} = ctx do
      add_permissions(ctx, ["organization.view", "organization.okta.view"])

      conn =
        conn
        |> get(organization_okta_path(conn, :form))

      assert html_response(conn, 404)
    end

    test "If user can view okta settings, but can't manage them", %{conn: conn} = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      conn =
        conn
        |> get(organization_okta_path(conn, :form))

      assert html_response(conn, 200) =~ "Save"
    end

    test "it renders session expiration days field with default", %{conn: conn} = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      conn =
        conn
        |> get(organization_okta_path(conn, :form))

      html = html_response(conn, 200)
      assert html =~ "Session expiration (days)"
      assert html =~ "name=\"okta_integration[session_expiration_days]\""
      assert html =~ "value=\"#{default_session_expiration_days()}\""
    end

    test "it hides session expiration field when editing existing integration",
         %{
           conn: conn
         } = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      DB.insert(:okta_integrations, %{
        id: Ecto.UUID.generate(),
        org_id: ctx.organization_id,
        creator_id: ctx.user_id,
        sso_url: "https://example.okta.com",
        saml_issuer: "https://example.okta.com",
        saml_certificate: "test-certificate",
        jit_provisioning_enabled: true,
        session_expiration_minutes: default_session_expiration_minutes(),
        created_at: Support.Stubs.Time.now(),
        updated_at: Support.Stubs.Time.now()
      })

      conn =
        conn
        |> get(organization_okta_path(conn, :form))

      html = html_response(conn, 200)
      refute html =~ "Session expiration (days)"
      refute html =~ "session_expiration_days"
    end
  end

  describe "create" do
    test "it sends session expiration minutes to okta service", %{conn: conn} = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      params = %{
        "sso_url" => "https://example.okta.com",
        "issuer" => "https://example.okta.com",
        "certificate" => "test-certificate",
        "jit_provisioning_enabled" => "true",
        "idempotency_token" => Ecto.UUID.generate(),
        "session_expiration_days" => "2"
      }

      conn =
        conn
        |> post(organization_okta_path(conn, :create), %{"okta_integration" => params})

      assert html_response(conn, 200) =~ "SCIM Authorization token"

      integration =
        DB.find_all_by(:okta_integrations, :org_id, ctx.organization_id)
        |> List.last()

      assert integration.org_id == ctx.organization_id
      assert integration.session_expiration_minutes == session_expiration_days_to_minutes(2)
    end

    test "it updates expiration without regenerating scim token", %{conn: conn} = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      DB.insert(:okta_integrations, %{
        id: Ecto.UUID.generate(),
        org_id: ctx.organization_id,
        creator_id: ctx.user_id,
        sso_url: "https://example.okta.com",
        saml_issuer: "https://example.okta.com",
        saml_certificate: "test-certificate",
        jit_provisioning_enabled: true,
        session_expiration_minutes: default_session_expiration_minutes(),
        created_at: Support.Stubs.Time.now(),
        updated_at: Support.Stubs.Time.now()
      })

      params = %{
        "idempotency_token" => Ecto.UUID.generate(),
        "session_expiration_days" => "2"
      }

      conn =
        conn
        |> post(organization_okta_path(conn, :create), %{"okta_integration" => params})

      assert redirected_to(conn) == organization_okta_path(conn, :show)

      integration =
        DB.find_all_by(:okta_integrations, :org_id, ctx.organization_id)
        |> List.last()

      assert integration.session_expiration_minutes == session_expiration_days_to_minutes(2)
    end

    test "editing existing integration requires certificate", %{conn: conn} = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      DB.insert(:okta_integrations, %{
        id: Ecto.UUID.generate(),
        org_id: ctx.organization_id,
        creator_id: ctx.user_id,
        sso_url: "https://example.okta.com",
        saml_issuer: "https://example.okta.com",
        saml_certificate: "test-certificate",
        jit_provisioning_enabled: true,
        session_expiration_minutes: default_session_expiration_minutes(),
        created_at: Support.Stubs.Time.now(),
        updated_at: Support.Stubs.Time.now()
      })

      params = %{
        "sso_url" => "https://example.okta.com",
        "issuer" => "https://example.okta.com",
        "certificate" => "",
        "jit_provisioning_enabled" => "false",
        "idempotency_token" => Ecto.UUID.generate()
      }

      conn =
        conn
        |> post(organization_okta_path(conn, :create), %{"okta_integration" => params})

      html = html_response(conn, 200)
      assert html =~ "Certificate can&#39;t be blank"
    end

    test "editing existing integration keeps session expiration unchanged",
         %{
           conn: conn
         } = ctx do
      add_permissions(ctx, [
        "organization.view",
        "organization.okta.view",
        "organization.okta.manage"
      ])

      DB.insert(:okta_integrations, %{
        id: Ecto.UUID.generate(),
        org_id: ctx.organization_id,
        creator_id: ctx.user_id,
        sso_url: "https://example.okta.com",
        saml_issuer: "https://example.okta.com",
        saml_certificate: "test-certificate",
        jit_provisioning_enabled: true,
        session_expiration_minutes: default_session_expiration_minutes(),
        created_at: Support.Stubs.Time.now(),
        updated_at: Support.Stubs.Time.now()
      })

      params = %{
        "sso_url" => "https://example.okta.com",
        "issuer" => "https://example.okta.com",
        "certificate" => "new-certificate",
        "jit_provisioning_enabled" => "true",
        "idempotency_token" => Ecto.UUID.generate(),
        "session_expiration_days" => "5"
      }

      conn =
        conn
        |> post(organization_okta_path(conn, :create), %{"okta_integration" => params})

      assert html_response(conn, 200) =~ "SCIM Authorization token"

      integration =
        DB.find_all_by(:okta_integrations, :org_id, ctx.organization_id)
        |> List.last()

      assert integration.session_expiration_minutes == default_session_expiration_minutes()
    end
  end

  defp add_permissions(ctx, permissions) do
    Support.Stubs.PermissionPatrol.add_permissions(
      ctx.organization_id,
      ctx.user_id,
      permissions
    )
  end

  defp default_session_expiration_minutes do
    Front.Okta.SessionExpiration.default_minutes()
  end

  defp default_session_expiration_days do
    Front.Okta.SessionExpiration.default_days()
  end

  defp session_expiration_days_to_minutes(days) do
    Front.Okta.SessionExpiration.days_to_minutes(days)
  end
end
