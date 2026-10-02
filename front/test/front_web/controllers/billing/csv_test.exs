defmodule FrontWeb.BillingController.CsvTest do
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

  describe "GET /billing/spending.csv" do
    test "serves the spending CSV as a non-renderable attachment", %{conn: conn} do
      conn = get(conn, "/billing/spending.csv")

      assert response(conn, 200)
      assert_csv_attachment(conn)
    end

    test "names the file after the spending period", %{conn: conn} do
      conn = get(conn, "/billing/spending.csv")

      assert [disposition] = get_resp_header(conn, "content-disposition")

      assert disposition =~
               ~r/^attachment; filename="hybrid\d{2}[a-z]{3}_\d{2}[a-z]{3}2\d{3}\.csv"$/
    end

    test "returns the spending items under a CSV header", %{conn: conn} do
      conn = get(conn, "/billing/spending.csv")

      assert [header | rows] = csv_lines(conn)
      assert header == "type,name,units,unit_price,total_price"
      assert Enum.any?(rows, &String.starts_with?(&1, "machine_time,e1-standard-2,"))
      assert Enum.any?(rows, &String.starts_with?(&1, "seats,Paid,"))
    end

    test "renders 404 when the user lacks the billing view permission", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      restrict_to_organization_view(org_id, user_id)

      conn = get(conn, "/billing/spending.csv")

      assert html_response(conn, 404) =~ "Page not found"
      assert get_resp_header(conn, "content-disposition") == []
    end
  end

  describe "GET /billing/projects.csv" do
    test "serves the projects CSV as a non-renderable attachment", %{conn: conn} do
      conn = get(conn, "/billing/projects.csv")

      assert response(conn, 200)
      assert_csv_attachment(conn)
    end

    test "prefixes the file name with projects_", %{conn: conn} do
      conn = get(conn, "/billing/projects.csv")

      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ ~s(attachment; filename="projects_hybrid)
    end

    test "returns one row per project spending group under a CSV header", %{conn: conn} do
      conn = get(conn, "/billing/projects.csv")

      assert [header | rows] = csv_lines(conn)
      assert header == "project_name,type,price"
      assert Enum.any?(rows, &String.starts_with?(&1, "billing,machine_time,"))
      assert Enum.any?(rows, &String.starts_with?(&1, "zebra,workflow_count,"))
    end

    test "renders 404 when the user lacks the billing view permission", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      restrict_to_organization_view(org_id, user_id)

      conn = get(conn, "/billing/projects.csv")

      assert html_response(conn, 404) =~ "Page not found"
      assert get_resp_header(conn, "content-disposition") == []
    end
  end

  # The CSV carries organization-supplied names, so the browser must never be
  # able to treat the body as a document.
  defp assert_csv_attachment(conn) do
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert [disposition] = get_resp_header(conn, "content-disposition")
    assert String.starts_with?(disposition, "attachment; ")
  end

  defp csv_lines(conn) do
    conn
    |> response(200)
    |> String.split("\r\n", trim: true)
  end

  defp restrict_to_organization_view(org_id, user_id) do
    Support.Stubs.PermissionPatrol.remove_all_permissions()
    Support.Stubs.PermissionPatrol.add_permissions(org_id, user_id, "organization.view")
  end
end
