defmodule Dashboardhub.PublicGrpcApi.Test do
  use ExUnit.Case

  @org_id "12345678-1234-5678-0000-010101010101"
  @user_id "12345678-1234-5678-0000-010101010102"

  @options [
    timeout: 1_000_000,
    metadata: %{
      "x-semaphore-user-id" => @user_id,
      "x-semaphore-org-id" => @org_id
    }
  ]

  alias Semaphore.Dashboards.V1alpha.{
    DashboardsApi,
    Dashboard,
    ListDashboardsRequest,
    GetDashboardRequest,
    DeleteDashboardRequest,
    UpdateDashboardRequest,
    Empty
  }

  alias Dashboardhub.Store

  setup do
    Store.clear!()

    :ok
  end

  describe ".create_dashboard" do
    test "saves the dashboard to the store" do
      create("dashboard")

      {:ok, dashboard} = Store.get(@org_id, "dashboard")

      assert dashboard.name == "dashboard"
      refute dashboard.id == nil
      refute dashboard.id == ""
      assert dashboard.org_id == @org_id
      refute dashboard.inserted_at == nil
      refute dashboard.inserted_at == ""
    end

    test "when saving succeeded => it returns the dashboard" do
      {:ok, response} = create("dashboard", "My Work")

      assert response.metadata.name == "dashboard"
      assert response.metadata.title == "My Work"
    end

    test "when not passing title => it copies title from name" do
      {:ok, response} = create("my-work")

      assert response.metadata.name == "my-work"
      assert response.metadata.title == "My Work"
    end

    test "raises error if the name is not unique" do
      {:ok, _} = create("dashboard")
      {:error, response2} = create("dashboard")

      assert response2.message == "name has already been taken"
      assert response2.status == 3
    end

    test "raises error if the name is in uuid format" do
      {:error, response} = create("ccac883d-9d2d-4ba8-8f0a-438489120ac4")

      assert response.message == "name should not be in uuid format"
      assert response.status == 3
    end

    test "raises error if the name is in invalid format" do
      {:error, response} = create("My Work")

      assert response.message ==
               "name should contain only lowercase letters a-z, numbers 0-9, and dashes, no spaces"

      assert response.status == 3
    end

    test "raises error if one of widgets has invalid type" do
      {:error, response} = create("My Work", "", "foo_bar")

      assert response.message ==
               "widget type should be one of list_pipelines, list_workflows, duration_pipelines, ratio_pipelines"

      assert response.status == 3
    end

    test "raises error if one of widgets has invalid filters" do
      filters = %{
        "foo" => "bar"
      }

      {:error, response} = create("list_pipelines", filters)

      assert response.message ==
               "widget list_pipelines should have only these filters project_id, branch, pipeline_file"

      assert response.status == 3
    end
  end

  describe ".update_dashboard" do
    test "when the dashboard is not present => it returns error" do
      req = %UpdateDashboardRequest{id_or_name: "foo", dashboard: dashboard()}

      {:error, response} = DashboardsApi.Stub.update_dashboard(channel(), req, @options)

      assert response.message == "Dashboard foo not found"
    end

    test "when saving succeeded => it returns the dashboard" do
      {:ok, dashboard} = create("foo")

      req = %UpdateDashboardRequest{
        id_or_name: dashboard.metadata.id,
        dashboard: dashboard("bar")
      }

      {:ok, response} = DashboardsApi.Stub.update_dashboard(channel(), req, @options)

      assert response.metadata.name == "bar"
    end

    test "when not passing title => it copies title from name" do
      {:ok, dashboard} = create("foo")

      req = %UpdateDashboardRequest{
        id_or_name: dashboard.metadata.id,
        dashboard: dashboard("my-work")
      }

      {:ok, response} = DashboardsApi.Stub.update_dashboard(channel(), req, @options)

      assert response.metadata.name == "my-work"
      assert response.metadata.title == "My Work"
    end

    test "raises error if the name is not unique" do
      {:ok, _} = create("foo")
      {:ok, dashboard} = create("bar")

      req = %UpdateDashboardRequest{
        id_or_name: dashboard.metadata.id,
        dashboard: dashboard("foo")
      }

      {:error, response} = DashboardsApi.Stub.update_dashboard(channel(), req, @options)

      assert response.message == "name has already been taken"
      assert response.status == 3
    end

    test "raises error if the name is in uuid format" do
      {:ok, dashboard} = create("bar")

      req = %UpdateDashboardRequest{
        id_or_name: dashboard.metadata.id,
        dashboard: dashboard(Ecto.UUID.generate())
      }

      {:error, response} = DashboardsApi.Stub.update_dashboard(channel(), req, @options)

      assert response.message == "name should not be in uuid format"
      assert response.status == 3
    end

    test "raises error if the name is in invalid format" do
      {:ok, dashboard} = create("bar")

      req = %UpdateDashboardRequest{
        id_or_name: dashboard.metadata.id,
        dashboard: dashboard("My Work")
      }

      {:error, response} = DashboardsApi.Stub.update_dashboard(channel(), req, @options)

      assert response.message ==
               "name should contain only lowercase letters a-z, numbers 0-9, and dashes, no spaces"

      assert response.status == 3
    end

    test "raises error if one of widgets has invalid type" do
      {:ok, dashboard} = create("bar")

      req = %UpdateDashboardRequest{
        id_or_name: dashboard.metadata.id,
        dashboard: dashboard("My Work", "", "foo_bar")
      }

      {:error, response} = DashboardsApi.Stub.update_dashboard(channel(), req, @options)

      assert response.message ==
               "widget type should be one of list_pipelines, list_workflows, duration_pipelines, ratio_pipelines"

      assert response.status == 3
    end

    test "raises error if one of widgets has invalid filters" do
      filters = %{
        "foo" => "bar"
      }

      {:ok, dashboard} = create("bar")

      req = %UpdateDashboardRequest{
        id_or_name: dashboard.metadata.id,
        dashboard: dashboard("list_pipelines", filters)
      }

      {:error, response} = DashboardsApi.Stub.update_dashboard(channel(), req, @options)

      assert response.message ==
               "widget list_pipelines should have only these filters project_id, branch, pipeline_file"

      assert response.status == 3
    end
  end

  describe ".list_dashboards" do
    test "when the users is authorized to see dashboards => it returns dashboards" do
      create("dashboard-1")
      create("dashboard-2")

      req = %ListDashboardsRequest{}

      {:ok, response} = DashboardsApi.Stub.list_dashboards(channel(), req, @options)

      assert Enum.count(response.dashboards) == 2

      assert Enum.map(response.dashboards, fn s -> s.metadata.name end) |> Enum.sort() == [
               "dashboard-1",
               "dashboard-2"
             ]
    end
  end

  describe ".get_dashboard" do
    test "when the users is authorized to see dashboard and we are fetching by name => it returns dashboard" do
      create()

      req = %GetDashboardRequest{id_or_name: "dashboard"}

      {:ok, response} = DashboardsApi.Stub.get_dashboard(channel(), req, @options)

      assert response.metadata.name == "dashboard"
    end

    test "when the users is authorized to see dashboard and we are fetching by id => it returns dashboard" do
      {:ok, dashboard} = create()

      req = %GetDashboardRequest{id_or_name: dashboard.metadata.id}

      {:ok, response} = DashboardsApi.Stub.get_dashboard(channel(), req, @options)

      assert response.metadata.id == dashboard.metadata.id
    end

    test "when the dashboard is not present => it returns error" do
      req = %GetDashboardRequest{id_or_name: "foo"}

      {:error, response} = DashboardsApi.Stub.get_dashboard(channel(), req, @options)

      assert response.message == "Dashboard foo not found"
    end
  end

  describe ".delete_dashboard" do
    test "deletes existing dashboards and returns empty response" do
      create("dashboard")

      assert {:ok, _} = Store.get(@org_id, "dashboard")

      req = %DeleteDashboardRequest{id_or_name: "dashboard"}

      {:ok, response} = DashboardsApi.Stub.delete_dashboard(channel(), req, @options)

      assert response == %Empty{}
      assert {:error, :not_found} = Store.get(@org_id, "dashboard")
    end

    test "raise error if trying to delete a non-existing dashboard" do
      assert {:error, :not_found} = Store.get(@org_id, "dashboard")

      req = %DeleteDashboardRequest{id_or_name: "dashboard"}

      {:error, response} = DashboardsApi.Stub.delete_dashboard(channel(), req, @options)

      assert response.message == "Dashboard dashboard not found"
    end
  end

  def create, do: create(dashboard())
  def create(name) when is_binary(name), do: create(dashboard(name))

  def create(dashboard) do
    DashboardsApi.Stub.create_dashboard(channel(), dashboard, @options)
  end

  def create(widget_type, filters) when is_map(filters),
    do: create(dashboard(widget_type, filters))

  def create(name, title), do: create(dashboard(name, title))
  def create(name, title, widget_type), do: create(dashboard(name, title, widget_type))

  defp dashboard(widget_type, filters) when is_map(filters),
    do: dashboard("dashboard", "title", widget_type, filters)

  defp dashboard(
         name \\ "dashboard",
         title \\ "",
         widget_type \\ "list_pipelines",
         filters \\ %{}
       ) do
    %Dashboard{
      metadata: %Dashboard.Metadata{name: name, title: title},
      spec: %Dashboard.Spec{
        widgets: [
          %Dashboard.Spec.Widget{
            name: "Widget 1",
            type: widget_type,
            filters: filters
          }
        ]
      }
    }
  end

  defp channel do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    channel
  end
end
