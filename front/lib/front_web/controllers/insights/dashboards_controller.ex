defmodule FrontWeb.Insights.DashboardsController do
  use FrontWeb, :controller
  alias Front.Audit
  alias Front.Models
  alias FrontWeb.Plugs
  require Logger

  plug(
    Plugs.ProjectAuthorization
    when action in [
           :index,
           :create,
           :update,
           :destroy,
           :show_item,
           :create_item,
           :update_item,
           :destroy_item
         ]
  )

  def index(conn, _params) do
    Watchman.benchmark("insights.dashboards.index.duration", fn ->
      project = conn.assigns.project

      case Models.MetricsDashboards.list(project.id) do
        {:ok, dashboards} ->
          render(conn, "index.json", dashboards: dashboards)

        {:error, error} ->
          json(conn, %{error: error})
      end
    end)
  end

  def create(conn, _params) do
    Watchman.benchmark("insights.dashboards.create.duration", fn ->
      project = conn.assigns.project
      org_id = conn.assigns.organization_id
      name = conn.body_params["name"]

      case Models.MetricsDashboards.create(name, project.id, org_id) do
        {:ok, dashboard} ->
          log_create(conn, name, project)

          render(conn, "show.json", dashboard: dashboard)

        {:error, error} ->
          json(conn, %{error: error})
      end
    end)
  end

  defp log_create(conn, dashboard_name, project) do
    conn
    |> Audit.new(:CustomDashboard, :Added)
    |> Audit.add(:resource_name, dashboard_name)
    |> Audit.add(:description, "New Dashboard Added")
    |> Audit.metadata(project_id: project.id)
    |> Audit.log()
  end

  def update(conn, params) do
    Watchman.benchmark("insights.dashboards.update.duration", fn ->
      dashboard_id = params["dashboard_id"]
      name = conn.body_params["name"]

      case Models.MetricsDashboards.update(dashboard_id, name) do
        {:ok, dashboard} ->
          log_update(conn, dashboard_id, name)

          render(conn, "show.json", dashboard: dashboard)

        {:error, error} ->
          json(conn, %{error: error})
      end
    end)
  end

  defp log_update(conn, dashboard_id, dashboard_name) do
    conn
    |> Audit.new(:CustomDashboard, :Modified)
    |> Audit.add(:resource_name, dashboard_name)
    |> Audit.add(:description, "Dashboard Modified")
    |> Audit.metadata(dashboard_id: dashboard_id)
    |> Audit.log()
  end

  def destroy(conn, params) do
    Watchman.benchmark("insights.dashboards.destroy.duration", fn ->
      dashboard_id = params["dashboard_id"]

      case Models.MetricsDashboards.delete(dashboard_id) do
        {:ok, _} ->
          log_delete(conn, dashboard_id)

          json(conn, %{success: true})

        {:error, error} ->
          json(conn, %{error: error})
      end
    end)
  end

  defp log_delete(conn, dashboard_id) do
    conn
    |> Audit.new(:CustomDashboard, :Removed)
    |> Audit.add(:description, "Dashboard Removed")
    |> Audit.metadata(dashboard_id: dashboard_id)
    |> Audit.log()
  end

  def show_item(conn, params) do
    Watchman.benchmark("insights.dashboards.destroy.duration", fn ->
      Logger.info("hello")
      item_id = params["item_id"]

      case Models.MetricsDashboardItems.find(item_id) do
        {:ok, item} ->
          json(conn, %{item: item})

        {:error, error} ->
          json(conn, %{error: error})
      end
    end)
  end

  def create_item(conn, params) do
    Watchman.benchmark("insights.dashboards.create_dashboard_item.duration", fn ->
      dashboard_id = conn.params["dashboard_id"]

      name = params["dashboardName"]
      branch_name = params["branchName"]
      pipeline_file_name = params["pipelineFileName"]

      metric = params["metric"] || "0"
      goal = params["goal"] || ""
      notes = params["notes"] || ""
      m = String.to_integer(metric)

      case Models.MetricsDashboardItems.create(
             dashboard_id,
             %{
               name: name,
               branch_name: branch_name,
               pipeline_file_name: pipeline_file_name,
               metric: m,
               goal: goal,
               notes: notes
             }
           ) do
        {:ok, dashboard_item} ->
          log_create_item(conn, dashboard_id, name)

          json(conn, %{item: dashboard_item.item})

        {:error, error} ->
          json(conn, %{error: error})
      end
    end)
  end

  defp log_create_item(conn, dashboard_id, item_name) do
    conn
    |> Audit.new(:CustomDashboardItem, :Added)
    |> Audit.add(:resource_name, item_name)
    |> Audit.add(:description, "New Dashboard Item Added")
    |> Audit.metadata(dashboard_id: dashboard_id)
    |> Audit.log()
  end

  def update_item(conn, params) do
    Watchman.benchmark("insights.dashboards.update_item.duration", fn ->
      item_id = params["item_id"]
      name = conn.body_params["name"]
      description = conn.body_params["description"]

      with {:ok, _} <- Models.MetricsDashboardItems.update(item_id, name),
           {:ok, _} <- Models.MetricsDashboardItems.update_description(item_id, description) do
        log_update_item(conn, item_id, name)
        log_item_description_change(conn, item_id, description)

        json(conn, %{success: true})
      else
        {:error, error} ->
          json(conn, %{error: error})
      end
    end)
  end

  defp log_update_item(conn, item_id, name) do
    conn
    |> Audit.new(:CustomDashboardItem, :Modified)
    |> Audit.add(:resource_name, name)
    |> Audit.add(:description, "Dashboard Item Modified")
    |> Audit.metadata(item_id: item_id)
    |> Audit.log()
  end

  defp log_item_description_change(conn, item_id, description) do
    conn
    |> Audit.new(:CustomDashboardItem, :Modified)
    |> Audit.add(:description, "Dashboard Item Description Modified")
    |> Audit.metadata(item_id: item_id)
    |> Audit.metadata(description: description)
    |> Audit.log()
  end

  def destroy_item(conn, params) do
    Watchman.benchmark("insights.dashboards.destroy_item.duration", fn ->
      item_id = params["item_id"]

      case Models.MetricsDashboardItems.delete(item_id) do
        {:ok, _} ->
          log_item_delete(conn, item_id)

          json(conn, %{success: true})

        {:error, error} ->
          json(conn, %{error: error})
      end
    end)
  end

  defp log_item_delete(conn, item_id) do
    conn
    |> Audit.new(:CustomDashboardItem, :Removed)
    |> Audit.add(:description, "Dashboard Item Removed")
    |> Audit.metadata(item_id: item_id)
    |> Audit.log()
  end
end
