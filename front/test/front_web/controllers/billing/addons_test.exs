defmodule FrontWeb.BillingController.AddonsTest do
  use FrontWeb.ConnCase

  setup %{conn: conn} do
    Support.Stubs.build_shared_factories()

    org_id = Support.Stubs.Organization.default_org_id()
    user_id = Support.Stubs.User.default_user_id()

    Support.Stubs.Billing.set_org_defaults(org_id)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    [conn: conn, org_id: org_id, user_id: user_id]
  end

  describe "GET /billing/addons.json" do
    test "returns addon groups with their addons", %{conn: conn} do
      conn = get(conn, "/billing/addons.json")

      response = json_response(conn, 200)
      groups = response["groups"]

      assert length(groups) == 2

      support_group = Enum.find(groups, &(&1["name"] == "support"))
      assert support_group["display_name"] == "Support"
      assert support_group["description"] == "Choose a support tier for your organization."
      assert support_group["type"] == "exclusive"
      assert length(support_group["addons"]) == 4

      first_addon = hd(support_group["addons"])
      assert first_addon["name"] == "support-tier-1"
      assert first_addon["display_name"] == "Community"
      assert first_addon["price"] == "$ 0.00"
      assert first_addon["enabled"] == true
      assert first_addon["modifiable"] == true

      enterprise_addon = List.last(support_group["addons"])
      assert enterprise_addon["name"] == "support-tier-4"
      assert enterprise_addon["modifiable"] == true
    end

    test "returns success group", %{conn: conn} do
      conn = get(conn, "/billing/addons.json")

      response = json_response(conn, 200)
      groups = response["groups"]

      success_group = Enum.find(groups, &(&1["name"] == "success"))
      assert success_group["display_name"] == "Success"
      assert success_group["type"] == "exclusive"
      assert length(success_group["addons"]) == 4

      first_addon = hd(success_group["addons"])
      assert first_addon["enabled"] == false
    end

    test "returns empty json when user lacks billing view permission", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.add_permissions(
        org_id,
        user_id,
        "organization.view"
      )

      conn = get(conn, "/billing/addons.json")

      assert json_response(conn, 200) == %{}
    end
  end

  describe "POST /billing/update_addon.json" do
    test "enables an addon", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/billing/update_addon.json", %{
          addon_name: "support-tier-2",
          enabled: true
        })

      response = json_response(conn, 200)
      assert response["ok"] == true
    end

    test "disables an addon", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/billing/update_addon.json", %{
          addon_name: "support-tier-1",
          enabled: false
        })

      response = json_response(conn, 200)
      assert response["ok"] == true
    end

    test "returns empty json when user lacks billing view permission", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.add_permissions(
        org_id,
        user_id,
        "organization.view"
      )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/billing/update_addon.json", %{
          addon_name: "support-tier-2",
          enabled: true
        })

      assert json_response(conn, 200) == %{}
    end

    test "returns 403 when user has view but not manage permission", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      Support.Stubs.PermissionPatrol.add_permissions(
        org_id,
        user_id,
        ["organization.view", "organization.plans_and_billing.view"]
      )

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/billing/update_addon.json", %{
          addon_name: "support-tier-2",
          enabled: true
        })

      assert conn.status in [403, 404]
    end
  end
end
