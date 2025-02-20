defmodule FrontWeb.OrganizationJWTConfigControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user_id = DB.first(:users) |> Map.get(:id)
    org_id = DB.first(:organizations) |> Map.get(:id)

    Support.Stubs.PermissionPatrol.remove_all_permissions()

    Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
      "organization.general_settings.view"
    ])

    Support.Stubs.Feature.enable_feature(org_id, "open_id_connect_filter")

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    [
      conn: conn,
      org_id: org_id,
      user_id: user_id
    ]
  end

  describe "GET show" do
    test "when user has view permission => shows the configuration", %{conn: conn} do
      conn = get(conn, "/jwt_config")

      response = html_response(conn, 200)
      assert response =~ "OIDC Token"
      assert response =~ "OIDC Token Configuration"

      # Test AWS tag indicator
      assert response =~ "AWS tag"

      # Test mandatory claim indicator
      assert response =~
               "Required"

      # Verify specific claims and their properties
      # AWS tag claim
      assert response =~ "branch"
      # Mandatory claim
      assert response =~ "prj_id"
      # Regular claim with AWS tag
      assert response =~ "pr_branch"
    end

    test "mandatory claims are always checked and disabled", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.general_settings.manage"
      ])

      conn = get(conn, "/jwt_config")
      response = html_response(conn, 200)

      # Verify mandatory claim (prj_id) has a checked and disabled checkbox
      assert response =~ ~s(name="claims[prj_id][is_active]" type="hidden" value="true")

      assert response =~
               ~s(<input checked class="checkbox" disabled id="claims[prj_id][is_active]" name="claims[prj_id][is_active]" type="checkbox")
    end

    test "AWS tag claims are properly marked", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.general_settings.manage"
      ])

      conn = get(conn, "/jwt_config")
      response = html_response(conn, 200)

      # Test for branch claim with AWS tag
      assert response =~ "branch"

      assert response =~ "AWS tag"

      # Test for pr_branch claim with AWS tag
      assert response =~ "pr_branch"

      # Verify non-AWS claim (prj_id) doesn't have AWS tag
      assert response =~ "prj_id"
      refute response =~ ~s(prj_id.*AWS tag</span>)
    end

    test "when user lacks view permission => shows not found", %{conn: conn} do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      conn = get(conn, "/jwt_config")

      assert html_response(conn, 404) =~ "404 Page Not Found"
    end

    test "when feature is disabled => shows feature disabled message", %{
      conn: conn,
      org_id: org_id
    } do
      Support.Stubs.Feature.disable_feature(org_id, "open_id_connect_filter")

      conn = get(conn, "/jwt_config")

      assert html_response(conn, 404)
    end

    test "when user has only view permission => shows read-only view", %{conn: conn} do
      conn = get(conn, "/jwt_config")

      assert html_response(conn, 200) =~ "OIDC Token Configuration"
      assert html_response(conn, 200) =~ "You have view-only access"
      refute html_response(conn, 200) =~ "Save Changes"
    end

    test "when user has manage permission => shows editable form", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.general_settings.manage"
      ])

      conn = get(conn, "/jwt_config")

      assert html_response(conn, 200) =~ "OIDC Token Configuration"
      assert html_response(conn, 200) =~ "Save Changes"
      refute html_response(conn, 200) =~ "You have view-only access"
    end
  end

  describe "POST update" do
    setup %{user_id: user_id, org_id: org_id} = config do
      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.general_settings.manage",
        "organization.general_settings.view"
      ])

      Support.Stubs.Feature.enable_feature(org_id, "open_id_connect_filter")

      config
    end

    test "when user has manage permission => updates the configuration", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      params = %{
        "claims" => %{
          "branch" => %{"is_active" => "true"},
          "prj_id" => %{"is_active" => "true"},
          "pr_branch" => %{"is_active" => "false"},
          "ppl_id" => %{"is_active" => "false"},
          "https://aws.amazon.com/tags" => %{"is_active" => "true"}
        }
      }

      conn = post(conn, "/jwt_config", params)

      assert redirected_to(conn) == "/jwt_config"
      assert get_flash(conn, :notice) =~ "OIDC Token configuration updated successfully"

      conn =
        recycle(conn)
        |> put_req_header("x-semaphore-org-id", org_id)
        |> put_req_header("x-semaphore-user-id", user_id)

      # Verify the claims were updated correctly
      conn = get(conn, organization_jwt_config_path(conn, :show))
      response = html_response(conn, 200)

      # Check branch claim is active
      assert response =~
               ~s(<input checked class="checkbox" id="claims[branch][is_active]" name="claims[branch][is_active]" type="checkbox")

      # Check pr_branch claim is not active
      assert response =~
               ~s(<input class="checkbox" id="claims[pr_branch][is_active]" name="claims[pr_branch][is_active]" type="checkbox")

      # Check AWS tags claim is active
      assert response =~
               ~s(<input checked class="checkbox" id="claims[https://aws.amazon.com/tags][is_active]" name="claims[https://aws.amazon.com/tags][is_active]" type="checkbox")
    end

    test "when user lacks manage permission => returns not found", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, [
        "organization.general_settings.view"
      ])

      params = %{
        "claims" => %{
          "branch" => %{"is_active" => "true"}
        }
      }

      conn = post(conn, "/jwt_config", params)
      assert html_response(conn, 404)
    end

    test "when feature is disabled => returns not found", %{conn: conn, org_id: org_id} do
      Support.Stubs.Feature.disable_feature(org_id, "open_id_connect_filter")

      params = %{
        "claims" => %{
          "branch" => %{"is_active" => "true"}
        }
      }

      conn = post(conn, "/jwt_config", params)
      assert html_response(conn, 404)
    end

    test "when update fails => shows error message", %{conn: conn} do
      # Simulate a failed update by returning an error response
      GrpcMock.stub(SecretMock, :update_jwt_config, fn _, _ ->
        {:error, %{message: "Failed to update OIDC Token configuration"}}
      end)

      params = %{
        "claims" => %{
          "branch" => %{"is_active" => "true"}
        }
      }

      conn = post(conn, "/jwt_config", params)
      assert redirected_to(conn) == "/jwt_config"
      assert get_flash(conn, :alert) =~ "Failed to update OIDC Token configuration"
    end
  end
end
