defmodule Router.Dashboards.UpdateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      dashboard_id = UUID.uuid4()
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
         dashboard_id: dashboard_id,
         dashboard: dashboard
       }}
    end

    test "update a dashboard", ctx do
      dashboard = construct_dashboard()

      {:ok, response} = update_dashboard(ctx, ctx.dashboard.id, dashboard)
      updated_dashboard = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(updated_dashboard)
      assert dashboard.metadata.name == updated_dashboard["metadata"]["name"]
    end

    test "without specified name in spec => fail", ctx do
      default_dashboard = construct_dashboard()

      dashboard =
        default_dashboard
        |> Map.put(:spec, Map.delete(default_dashboard.spec, :display_name))

      {:ok, response} = update_dashboard(ctx, ctx.dashboard.id, dashboard)
      assert 422 == response.status_code
    end

    test "random version => fail", ctx do
      dashboard = construct_dashboard() |> Map.put(:apiVersion, "v3")
      {:ok, response} = update_dashboard(ctx, ctx.dashboard.id, dashboard)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      dashboard = construct_dashboard() |> Map.put(:kind, "DashboardS")
      {:ok, response} = update_dashboard(ctx, ctx.dashboard.id, dashboard)

      assert 422 == response.status_code
    end

    test "updating a dashboard that is not owned by the requester org", ctx do
      wrong_org_id = UUID.uuid4()
      dashboard = Support.Stubs.Dashboards.create(%{id: wrong_org_id})

      GrpcMock.stub(DashboardMock, :describe, fn _req, _ ->
        %InternalApi.Dashboardhub.DescribeResponse{dashboard: dashboard.api_model}
      end)

      dashboard = construct_dashboard(%{display_name: "A Dashboard"})

      {:ok, response} = update_dashboard(ctx, ctx.dashboard.id, dashboard)
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

      #  permissions are not enough to modify a dashboard, so user is unauthorized for the operation.
      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.view")

      {:ok, %{org_id: org_id, user_id: user_id, dashboard_id: dashboard_id, dashboard: dashboard}}
    end

    test "update a dashboard", ctx do
      dashboard = construct_dashboard()
      {:ok, response} = update_dashboard(ctx, ctx.dashboard.id, dashboard)
      _updated_dashboard = Jason.decode!(response.body)

      assert 404 == response.status_code

      spec = PublicAPI.ApiSpec.spec()
      assert_schema(response, "Error", spec)
    end
  end

  defp construct_dashboard(params \\ %{}) do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.Dashboards.Dashboard.schema())

    params =
      %{
        organization_id: default.metadata.organization.id,
        display_name: default.spec.display_name,
        pipeline_file: Enum.at(default.spec.widgets, 0).filters.pipeline_file,
        reference: Enum.at(default.spec.widgets, 0).filters.reference,
        project: nil
      }
      |> Map.merge(params)

    widgets = [
      %{
        name: Enum.at(default.spec.widgets, 0).name,
        type: Enum.at(default.spec.widgets, 0).type,
        filters: %{
          pipeline_file: params.pipeline_file,
          reference: params.reference,
          project: params.project
        }
      }
    ]

    organization = %{
      id: params.organization_id,
      name: default.metadata.organization.name
    }

    default
    |> Map.put(:metadata, Map.put(default.metadata, :organization, organization))
    |> Map.put(:spec, Map.put(default.spec, :display_name, params.display_name))
    |> Map.put(:spec, Map.put(default.spec, :widgets, widgets))
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Dashboard", spec)
  end

  defp update_dashboard(ctx, id_or_name, dashboard) do
    url = url() <> "/dashboards/#{id_or_name}"
    body = Jason.encode!(dashboard)

    HTTPoison.post(url, body, headers(ctx))
  end
end
