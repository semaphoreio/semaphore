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
  end

  defp add_permissions(ctx, permissions) do
    Support.Stubs.PermissionPatrol.add_permissions(
      ctx.organization_id,
      ctx.user_id,
      permissions
    )
  end
end
