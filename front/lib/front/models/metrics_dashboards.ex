defmodule Front.Models.MetricsDashboards do
  @moduledoc """
  This model is used to fetch metric dashboard data for a project.
  """

  alias Front.Clients.Velocity, as: VelocityClient
  alias InternalApi.Velocity, as: API
  require Logger

  def list(project_id) do
    VelocityClient.list_metrics_dashboards(%API.ListMetricsDashboardsRequest{
      project_id: project_id
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error fetching metrics dashboards: #{inspect(error)}")
        error
    end
  end

  def create(name, project_id, org_id) do
    VelocityClient.create_metrics_dashboard(%API.CreateMetricsDashboardRequest{
      project_id: project_id,
      organization_id: org_id,
      name: name
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error creating metrics dashboard: #{inspect(error)}")
        error
    end
  end

  def delete(dashboard_id) do
    VelocityClient.delete_metrics_dashboard(%API.DeleteMetricsDashboardRequest{
      id: dashboard_id
    })
    |> case do
      {:ok, _} ->
        {:ok, %{sucess: true}}

      error ->
        Logger.error("Error deleting metrics dashboard: #{inspect(error)}")
        error
    end
  end

  def update(dashboard_id, name) do
    VelocityClient.update_metrics_dashboard(%API.UpdateMetricsDashboardRequest{
      id: dashboard_id,
      name: name
    })
    |> case do
      {:ok, _} ->
        {:ok, %{sucess: true}}

      error ->
        Logger.error("Error updating metrics dashboard: #{inspect(error)}")
        error
    end
  end
end
