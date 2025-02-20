defmodule Router.Dashboards.DescribeTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      org = Support.Stubs.Organization.create(org_id: org_id)
      dashboard = Support.Stubs.Dashboards.create(org)

      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.view")

      {:ok,
       %{
         org_id: org_id,
         org: org,
         user_id: user_id,
         dashboard_id: dashboard.id,
         dashboard_name: dashboard.name
       }}
    end

    test "describe a dashboard by id", ctx do
      {:ok, response} = get_dashboard(ctx, ctx.dashboard_id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a dashboard by name", ctx do
      {:ok, response} = get_dashboard(ctx, ctx.dashboard_name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a dashboard without project filter", ctx do
      branch = "master"
      dashboard = Support.Stubs.Dashboards.create(ctx.org, filters: %{"branch" => branch})

      {:ok, response} = get_dashboard(ctx, dashboard.id)
      assert 200 == response.status_code
      resp = Jason.decode!(response.body)

      assert %{
               "spec" => %{
                 "widgets" => [widget]
               }
             } = resp

      assert widget["filters"]["project"] == nil
      assert widget["filters"]["pipeline_file"] == nil
      assert widget["filters"]["reference"] == "refs/heads/#{branch}"

      check_response(response)
    end

    test "describe a dashboard with non existing project", ctx do
      project_id = UUID.uuid4()
      dashboard = Support.Stubs.Dashboards.create(ctx.org, filters: %{"project_id" => project_id})

      {:ok, response} = get_dashboard(ctx, dashboard.id)
      assert 200 == response.status_code
      resp = Jason.decode!(response.body)

      assert %{
               "spec" => %{
                 "widgets" => [
                   %{"filters" => %{"project" => %{"id" => p_id, "name" => p_name}}}
                 ]
               }
             } = resp

      assert project_id == p_id
      assert nil == p_name

      check_response(response)
    end

    test "describe a dashboard with existing project", ctx do
      project_id = UUID.uuid4()

      project =
        Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id)

      dashboard = Support.Stubs.Dashboards.create(ctx.org, filters: %{"project_id" => project_id})

      {:ok, response} = get_dashboard(ctx, dashboard.id)
      assert 200 == response.status_code
      resp = Jason.decode!(response.body)

      assert %{
               "spec" => %{
                 "widgets" => [
                   %{"filters" => %{"project" => %{"id" => p_id, "name" => p_name}}}
                 ]
               }
             } = resp

      assert project_id == p_id
      assert project.name == p_name

      check_response(response)
    end

    test "describe a non-existent dashboard", ctx do
      {:ok, response} = get_dashboard(ctx, "non-existent")
      assert 404 == response.status_code
    end

    test "describe a dashboard that is not owned by the requester org", ctx do
      wrong_org_id = UUID.uuid4()
      dashboard = Support.Stubs.Dashboards.create(%{id: wrong_org_id})

      GrpcMock.stub(DashboardMock, :describe, fn _req, _ ->
        %InternalApi.Dashboardhub.DescribeResponse{dashboard: dashboard.api_model}
      end)

      {:ok, response} = get_dashboard(ctx, dashboard.id)
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

    test "describe a dashboard by id", ctx do
      {:ok, response} = get_dashboard(ctx, ctx.dashboard_id)
      assert 404 == response.status_code
    end

    test "describe a dashboard by name", ctx do
      {:ok, response} = get_dashboard(ctx, ctx.dashboard_name)
      assert 404 == response.status_code
    end

    test "describe a non-existent dashboard", ctx do
      {:ok, response} = get_dashboard(ctx, "non-existent")
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "Dashboard", spec)
  end

  defp get_dashboard(ctx, id_or_name) do
    url = url() <> "/dashboards/#{id_or_name}"

    HTTPoison.get(url, headers(ctx))
  end
end
