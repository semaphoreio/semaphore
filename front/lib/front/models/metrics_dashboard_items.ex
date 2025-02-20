defmodule Front.Models.MetricsDashboardItems do
  @moduledoc """
  This model is used to fetch metric dashboard items data for a project.
  """

  alias Front.Clients.Velocity, as: VelocityClient
  alias InternalApi.Velocity, as: API
  require Logger

  def find(item_id) do
    VelocityClient.describe_metrics_dashboard_item(%API.DescribeDashboardItemRequest{
      id: item_id
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error fetch metrics dashboard item: #{inspect(error)}")
        error
    end
  end

  def create(dashboard_id, item) do
    VelocityClient.create_metrics_dashboard_item(%API.CreateDashboardItemRequest{
      name: item.name,
      metrics_dashboard_id: dashboard_id,
      branch_name: item.branch_name,
      pipeline_file_name: item.pipeline_file_name,
      settings: %API.DashboardItemSettings{
        metric: item.metric,
        goal: item.goal
      },
      notes: item.notes
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error creating metrics dashboard item: #{inspect(error)}")
        error
    end
  end

  def delete(item_id) do
    VelocityClient.delete_metrics_dashboard_item(%API.DeleteDashboardItemRequest{
      id: item_id
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error deleting metrics dashboard item: #{inspect(error)}")
        error
    end
  end

  def update(item_id, name) do
    VelocityClient.update_metrics_dashboard_item(%API.UpdateDashboardItemRequest{
      id: item_id,
      name: name
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error updating metrics dashboard item: #{inspect(error)}")
        error
    end
  end

  def update_description(item_id, description) do
    VelocityClient.change_metrics_dashboard_item_description(%API.ChangeDashboardItemNotesRequest{
      id: item_id,
      notes: description
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error updating metrics dashboard item description: #{inspect(error)}")
        error
    end
  end
end
