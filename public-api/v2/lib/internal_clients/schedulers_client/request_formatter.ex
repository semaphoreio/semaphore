defmodule InternalClients.Schedulers.RequestFormatter do
  @moduledoc """
  Module formats the request using data received into protobuf
  messages suitable for gRPC communication with Guard RBAC service.
  """

  alias InternalApi.PeriodicScheduler, as: API
  import InternalClients.Common

  def form_request({API.ListRequest, params}) do
    {:ok,
     %API.ListRequest{
       organization_id: from_params!(params, :organization_id),
       project_id: from_params(params, :project_id, ""),
       requester_id: from_params(params, :requester_id, ""),
       page: from_params(params, :page, 1),
       page_size: from_params(params, :size, 100)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.ListKeysetRequest, params}) do
    {:ok,
     %API.ListKeysetRequest{
       organization_id: from_params!(params, :organization_id),
       project_id: from_params(params, :project_id, ""),
       query: from_params(params, :name, ""),
       page_token: from_params(params, :page_token, ""),
       page_size: from_params(params, :page_size, 20),
       direction: direction_from_params(params)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.DescribeRequest, params}) do
    {:ok,
     %API.DescribeRequest{
       id: from_params!(params, :task_id)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.PersistRequest, params}) do
    {:ok,
     %API.PersistRequest{
       id: from_params(params, :task_id),
       name: from_params!(params, :name),
       description: from_params(params, :description, ""),
       recurring: recurring_from_params(params),
       state: state_from_params(params),
       organization_id: from_params(params, :organization_id),
       project_id: from_params(params, :project_id),
       branch: from_params!(params, :branch),
       pipeline_file: from_params!(params, :pipeline_file),
       requester_id: from_params!(params, :requester_id),
       at: from_params(params, :cron_schedule, ""),
       parameters: from_params(params, :parameters)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.DeleteRequest, params}) do
    {:ok,
     %API.DeleteRequest{
       id: from_params!(params, :task_id),
       requester: from_params!(params, :requester_id)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.RunNowRequest, params}) do
    {:ok,
     %API.RunNowRequest{
       id: from_params!(params, :task_id),
       requester: from_params!(params, :requester_id),
       branch: from_params(params, :branch),
       pipeline_file: from_params(params, :pipeline_file),
       parameter_values: from_params(params, :parameters)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  defp state_from_params(params) do
    case from_params(params, :paused) do
      true -> :PAUSED
      false -> :ACTIVE
      nil -> :UNCHANGED
    end
  end

  defp direction_from_params(params) do
    case from_params(params, :direction) do
      "NEXT" -> :NEXT
      "PREV" -> :PREV
      "PREVIOUS" -> :PREV
      _ -> :NEXT
    end
  end

  defp recurring_from_params(params) do
    from_params(params, :cron_schedule, "") != ""
  end
end
