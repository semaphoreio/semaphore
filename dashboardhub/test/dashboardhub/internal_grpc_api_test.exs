defmodule Dashboardhub.InternalGrpcApi.Test do
  use ExUnit.Case

  @org_id "12345678-1234-5678-0000-010101010101"
  @user_id "12345678-1234-5678-0000-010101010102"

  @options [
    timeout: 1_000_000
  ]

  @metadata %InternalApi.Dashboardhub.RequestMeta{
    org_id: @org_id,
    user_id: @user_id
  }

  alias InternalApi.Dashboardhub.{
    CreateRequest,
    DescribeRequest,
    UpdateRequest,
    DestroyRequest,
    ListRequest,
    Dashboard,
    DestroyResponse
  }

  alias InternalApi.Dashboardhub.DashboardsService, as: DashboardsApi

  alias Dashboardhub.Store

  setup do
    Store.clear!()

    :ok
  end

  describe ".create" do
    test "saves the dashboard to the store" do
      {:ok, resp} = create("dashboard")

      {:ok, dashboard} = Store.get(@org_id, "dashboard")

      assert dashboard.name == "dashboard"
      assert resp.dashboard.metadata.name == "dashboard"
      refute dashboard.id == nil
      refute dashboard.id == ""
      assert resp.dashboard.metadata.id == dashboard.id
      assert dashboard.org_id == @org_id
      refute dashboard.inserted_at == nil
      refute dashboard.inserted_at == ""
    end

    test "when saving succeeded => it returns the dashboard" do
      {:ok, response} = create("dashboard", "My Work")

      assert response.dashboard.metadata.name == "dashboard"
      assert response.dashboard.metadata.title == "My Work"
    end

    test "when not passing title => it copies title from name" do
      {:ok, response} = create("my-work")

      assert response.dashboard.metadata.name == "my-work"
      assert response.dashboard.metadata.title == "My Work"
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

  describe ".update" do
    test "when the dashboard is not present => it returns error" do
      req = %UpdateRequest{id_or_name: "foo", dashboard: dashboard(), metadata: @metadata}

      {:error, response} = DashboardsApi.Stub.update(channel(), req, @options)

      assert response.message == "Dashboard foo not found"
    end

    test "when saving succeeded => it returns the dashboard" do
      {:ok, dashboard_req} = create("foo")

      req = %UpdateRequest{
        id_or_name: dashboard_req.dashboard.metadata.id,
        dashboard: dashboard("bar"),
        metadata: @metadata
      }

      {:ok, response} = DashboardsApi.Stub.update(channel(), req, @options)

      assert response.dashboard.metadata.name == "bar"
    end

    test "when not passing title => it copies title from name" do
      {:ok, dashboard_req} = create("foo")

      req = %UpdateRequest{
        id_or_name: dashboard_req.dashboard.metadata.id,
        dashboard: dashboard("my-work"),
        metadata: @metadata
      }

      {:ok, response} = DashboardsApi.Stub.update(channel(), req, @options)

      assert response.dashboard.metadata.name == "my-work"
      assert response.dashboard.metadata.title == "My Work"
    end

    test "raises error if the name is not unique" do
      {:ok, _} = create("foo")
      {:ok, create_response} = create("bar")

      req = %UpdateRequest{
        id_or_name: create_response.dashboard.metadata.id,
        dashboard: dashboard("foo"),
        metadata: @metadata
      }

      {:error, response} = DashboardsApi.Stub.update(channel(), req, @options)

      assert response.message == "name has already been taken"
      assert response.status == 3
    end

    test "raises error if the name is in uuid format" do
      {:ok, dashboard_req} = create("bar")

      req = %UpdateRequest{
        id_or_name: dashboard_req.dashboard.metadata.id,
        dashboard: dashboard(Ecto.UUID.generate()),
        metadata: @metadata
      }

      {:error, response} = DashboardsApi.Stub.update(channel(), req, @options)

      assert response.message == "name should not be in uuid format"
      assert response.status == 3
    end

    test "raises error if the name is in invalid format" do
      {:ok, dashboard_req} = create("bar")

      req = %UpdateRequest{
        id_or_name: dashboard_req.dashboard.metadata.id,
        dashboard: dashboard("My Work"),
        metadata: @metadata
      }

      {:error, response} = DashboardsApi.Stub.update(channel(), req, @options)

      assert response.message ==
               "name should contain only lowercase letters a-z, numbers 0-9, and dashes, no spaces"

      assert response.status == 3
    end

    test "raises error if one of widgets has invalid type" do
      {:ok, dashboard_req} = create("bar")

      req = %UpdateRequest{
        id_or_name: dashboard_req.dashboard.metadata.id,
        dashboard: dashboard("My Work", "", "foo_bar"),
        metadata: @metadata
      }

      {:error, response} = DashboardsApi.Stub.update(channel(), req, @options)

      assert response.message ==
               "widget type should be one of list_pipelines, list_workflows, duration_pipelines, ratio_pipelines"

      assert response.status == 3
    end

    test "raises error if one of widgets has invalid filters" do
      filters = %{
        "foo" => "bar"
      }

      {:ok, dashboard_req} = create("bar")

      req = %UpdateRequest{
        id_or_name: dashboard_req.dashboard.metadata.id,
        dashboard: dashboard("list_pipelines", filters),
        metadata: @metadata
      }

      {:error, response} = DashboardsApi.Stub.update(channel(), req, @options)

      assert response.message ==
               "widget list_pipelines should have only these filters project_id, branch, pipeline_file"

      assert response.status == 3
    end
  end

  describe ".lists" do
    test "when the users is authorized to see dashboards => it returns dashboards" do
      create("dashboard-1")
      create("dashboard-2")

      req = %ListRequest{metadata: @metadata}

      {:ok, response} = DashboardsApi.Stub.list(channel(), req, @options)

      assert Enum.count(response.dashboards) == 2

      assert Enum.map(response.dashboards, fn s -> s.metadata.name end) |> Enum.sort() == [
               "dashboard-1",
               "dashboard-2"
             ]
    end
  end

  describe ".describe" do
    test "when the users is authorized to see dashboard and we are fetching by name => it returns dashboard" do
      create()

      req = %DescribeRequest{id_or_name: "dashboard", metadata: @metadata}

      {:ok, response} = DashboardsApi.Stub.describe(channel(), req, @options)

      assert response.dashboard.metadata.name == "dashboard"
    end

    test "when the users is authorized to see dashboard and we are fetching by id => it returns dashboard" do
      {:ok, dashboard_req} = create()

      req = %DescribeRequest{id_or_name: dashboard_req.dashboard.metadata.id, metadata: @metadata}

      {:ok, response} = DashboardsApi.Stub.describe(channel(), req, @options)

      assert response.dashboard.metadata.id == dashboard_req.dashboard.metadata.id
    end

    test "when the dashboard is not present => it returns error" do
      req = %DescribeRequest{id_or_name: "foo", metadata: @metadata}

      {:error, response} = DashboardsApi.Stub.describe(channel(), req, @options)

      assert response.message == "Dashboard foo not found"
    end
  end

  describe ".destroy" do
    test "deletes existing dashboards and returns empty response" do
      create("dashboard")

      assert {:ok, dashboard} = Store.get(@org_id, "dashboard")

      req = %DestroyRequest{id_or_name: "dashboard", metadata: @metadata}

      {:ok, response} = DashboardsApi.Stub.destroy(channel(), req, @options)

      assert response == %DestroyResponse{id: dashboard.id}
      assert {:error, :not_found} = Store.get(@org_id, "dashboard")
    end

    test "raise error if trying to delete a non-existing dashboard" do
      assert {:error, :not_found} = Store.get(@org_id, "dashboard")

      req = %DestroyRequest{id_or_name: "dashboard", metadata: @metadata}

      {:error, response} = DashboardsApi.Stub.destroy(channel(), req, @options)

      assert response.message == "Dashboard dashboard not found"
    end
  end

  def create, do: create(dashboard())
  def create(name) when is_binary(name), do: create(dashboard(name))

  def create(dashboard) do
    DashboardsApi.Stub.create(
      channel(),
      %CreateRequest{dashboard: dashboard, metadata: @metadata},
      @options
    )
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
