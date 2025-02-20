defmodule Router.Dashboards.CreateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)

      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.manage")

      {:ok, %{org_id: org_id, user_id: user_id, org: org}}
    end

    test "create a dashboard", ctx do
      project_id = UUID.uuid4()

      project =
        Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id)

      dashboard =
        construct_dashboard(%{
          organization_id: ctx.org_id,
          project: %{id: project.id, name: project.name}
        })

      {:ok, response} = create_dashboard(ctx, dashboard)
      created_dashboard = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_dashboard)
      assert dashboard.metadata.name == created_dashboard["metadata"]["name"]
    end

    test "create a dashboard only with spec", ctx do
      project_id = UUID.uuid4()

      project =
        Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id)

      dashboard =
        construct_dashboard(%{
          organization_id: ctx.org_id,
          project: %{id: project.id, name: project.name}
        })
        |> Map.delete(:metadata)
        |> Map.delete(:apiVersion)
        |> Map.delete(:kind)

      {:ok, response} = create_dashboard(ctx, dashboard)
      created_dashboard = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_dashboard)
      assert dashboard.spec.display_name == created_dashboard["spec"]["display_name"]

      assert Enum.at(created_dashboard["spec"]["widgets"], 0)["filters"]["project"]["id"] ==
               project_id
    end

    test "create a dashboard with project by name", ctx do
      project_id = UUID.uuid4()

      project =
        Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id)

      dashboard =
        construct_dashboard(%{
          organization_id: ctx.org_id,
          project: %{name: project.name}
        })
        |> Map.delete(:metadata)
        |> Map.delete(:apiVersion)
        |> Map.delete(:kind)

      {:ok, response} = create_dashboard(ctx, dashboard)
      created_dashboard = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_dashboard)
      assert dashboard.spec.display_name == created_dashboard["spec"]["display_name"]

      assert Enum.at(created_dashboard["spec"]["widgets"], 0)["filters"]["project"]["id"] ==
               project_id
    end

    test "without specified name in spec => fail", ctx do
      default_dashboard = construct_dashboard()

      dashboard =
        default_dashboard
        |> Map.put(:spec, Map.delete(default_dashboard.spec, :display_name))

      {:ok, response} = create_dashboard(ctx, dashboard)
      assert 422 == response.status_code
    end

    test "create a dashboard with non existing project by id", ctx do
      project_id = UUID.uuid4()

      dashboard =
        construct_dashboard(%{
          organization_id: ctx.org_id,
          project: %{id: project_id}
        })

      {:ok, response} = create_dashboard(ctx, dashboard)
      error = Jason.decode!(response.body)

      assert 400 == response.status_code
      assert "Project #{project_id} not found" == error["message"]
    end

    test "create a dashboard with non existing project by name", ctx do
      project_name = "non-existing-project"

      dashboard =
        construct_dashboard(%{
          organization_id: ctx.org_id,
          project: %{name: project_name}
        })

      {:ok, response} = create_dashboard(ctx, dashboard)
      error = Jason.decode!(response.body)

      assert 400 == response.status_code
      assert "Project #{project_name} not found" == error["message"]
    end

    test "random version => fail", ctx do
      dashboard = construct_dashboard() |> Map.put(:apiVersion, "v3")
      {:ok, response} = create_dashboard(ctx, dashboard)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      dashboard = construct_dashboard() |> Map.put(:kind, "Foo")
      {:ok, response} = create_dashboard(ctx, dashboard)

      assert 422 == response.status_code
    end

    test "create a dashboard without filters", ctx do
      dashboard = %{
        spec: %{
          display_name: "My dashboard 1",
          widgets: [%{name: "widget1", type: "WORKFLOWS", filters: %{}}]
        }
      }

      {:ok, response} = create_dashboard(ctx, dashboard)
      created_dashboard = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_dashboard)
      assert dashboard.spec.display_name == created_dashboard["spec"]["display_name"]
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)

      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.view")

      {:ok, %{org_id: org_id, user_id: user_id, org: org}}
    end

    test "create a dashboard", ctx do
      dashboard = construct_dashboard()
      {:ok, response} = create_dashboard(ctx, dashboard)
      response_body = Jason.decode!(response.body)

      assert 404 == response.status_code
      api = PublicAPI.ApiSpec.spec()
      assert_schema(response_body, "Error", api)
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Dashboard", spec)
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

  defp create_dashboard(ctx, dashboard) do
    url = url() <> "/dashboards"

    body = Jason.encode!(dashboard)

    HTTPoison.post(url, body, headers(ctx))
  end
end
