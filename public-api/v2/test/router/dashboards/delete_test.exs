defmodule Router.Dashboards.DeleteTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      org = Support.Stubs.Organization.create(org_id: org_id)
      dashboard = Support.Stubs.Dashboards.create(org)

      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.manage")

      {:ok,
       %{
         org_id: org_id,
         org: org,
         user_id: user_id,
         dashboard_id: dashboard.id,
         dashboard_name: dashboard.name
       }}
    end

    test "delete a dashboard by id", ctx do
      {:ok, response} = delete_dashboard(ctx, ctx.dashboard_id)
      assert 204 == response.status_code
      check_response(response)
    end

    test "delete a dashboard by name", ctx do
      {:ok, response} = delete_dashboard(ctx, ctx.dashboard_name)
      assert 204 == response.status_code
      check_response(response)
    end

    test "delete a non-existent dashboard", ctx do
      {:ok, response} = delete_dashboard(ctx, "non-existent")
      assert 404 == response.status_code
    end

    test "delete a dashboard that is not owned by the requester org", ctx do
      wrong_org_id = UUID.uuid4()
      dashboard = Support.Stubs.Dashboards.create(%{id: wrong_org_id})

      GrpcMock.stub(DashboardMock, :describe, fn _req, _ ->
        %InternalApi.Dashboardhub.DescribeResponse{dashboard: dashboard.api_model}
      end)

      {:ok, response} = delete_dashboard(ctx, dashboard.id)
      assert 404 == response.status_code
      assert %{"message" => "Not found"} = Jason.decode!(response.body)
    end
  end

  describe "unauthorized users" do
    setup do
      dashboard_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      dashboard = Support.Stubs.Dashboards.create(%{id: org_id})

      {:ok,
       %{
         org_id: org_id,
         user_id: user_id,
         dashboard_id: dashboard_id,
         dashboard_name: dashboard.name
       }}
    end

    test "delete a dashboard by id", ctx do
      {:ok, response} = delete_dashboard(ctx, ctx.dashboard_id)
      assert 404 == response.status_code
    end

    test "delete a dashboard by name", ctx do
      {:ok, response} = delete_dashboard(ctx, ctx.dashboard_name)
      assert 404 == response.status_code
    end

    test "delete a non-existent dashboard", ctx do
      {:ok, response} = delete_dashboard(ctx, "non-existent")
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    assert response.body == ""
  end

  defp delete_dashboard(ctx, id_or_name) do
    url = url() <> "/dashboards/#{id_or_name}"

    HTTPoison.delete(url, headers(ctx))
  end
end
