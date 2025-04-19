defmodule InternalClients.Canvases.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into
  protobuf messages suitable for gRPC communication with canvas service.
  """

  require Logger

  alias InternalApi.Delivery, as: API
  import InternalClients.Common

  def form_request({API.CreateCanvasRequest, params}) do
    {:ok,
     %API.CreateCanvasRequest{
       name: from_params(params.metadata, :name),
       organization_id: from_params!(params, :organization_id),
       requester_id: from_params!(params, :user_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.DescribeCanvasRequest, params}) do
    {:ok,
     %API.DescribeCanvasRequest{
       id: from_params(params, :id),
       name: from_params(params, :name),
       organization_id: from_params!(params, :organization_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.CreateEventSourceRequest, params}) do
    {:ok,
     %API.CreateEventSourceRequest{
       name: from_params!(params.metadata, :name),
       canvas_id: from_params!(params, :canvas_id),
       organization_id: from_params!(params, :organization_id),
       requester_id: from_params!(params, :user_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.DescribeEventSourceRequest, params}) do
    {:ok,
     %API.DescribeEventSourceRequest{
       id: from_params(params, :id),
       name: from_params(params, :name),
       canvas_id: from_params(params, :canvas_id),
       organization_id: from_params(params, :organization_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.CreateStageRequest, params}) do
    {:ok,
     %API.CreateStageRequest{
       name: from_params(params.metadata, :name),
       canvas_id: from_params!(params, :canvas_id),
       organization_id: from_params!(params, :organization_id),
       requester_id: from_params!(params, :user_id),
       approval_required: from_params(params.spec, :approval_required),
       connections: stage_connections(params),
       run_template: from_params(params.spec, :run_template)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.DescribeStageRequest, params}) do
    {:ok,
     %API.DescribeStageRequest{
       id: from_params(params, :id),
       name: from_params(params, :name),
       canvas_id: from_params!(params, :canvas_id),
       organization_id: from_params!(params, :organization_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.ListEventSourcesRequest, params}) do
    {:ok,
     %API.ListEventSourcesRequest{
       canvas_id: from_params!(params, :canvas_id),
       organization_id: from_params!(params, :organization_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.ListStagesRequest, params}) do
    {:ok,
     %API.ListStagesRequest{
       canvas_id: from_params!(params, :canvas_id),
       organization_id: from_params!(params, :organization_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.ListStageEventsRequest, params}) do
    {:ok,
     %API.ListStageEventsRequest{
       canvas_id: from_params!(params, :canvas_id),
       organization_id: from_params!(params, :organization_id),
       stage_id: from_params!(params, :stage_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  def form_request({API.ApproveStageEventRequest, params}) do
    {:ok,
     %API.ApproveStageEventRequest{
       event_id: from_params!(params, :id),
       canvas_id: from_params!(params, :canvas_id),
       organization_id: from_params!(params, :organization_id),
       stage_id: from_params!(params, :stage_id)
     }}
  rescue
    e in RuntimeError ->
      error = %{
        message: e.message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      }

      {:error, {:user, error}}
  end

  defp stage_connections(params) do
    Enum.map(from_params(params.spec, :connections), fn c ->
      %API.Connection{
        type: connection_type(c.type),
        name: c.name,
        filter_operator: filter_operator(c.filter_operator),
        filters: connection_filters(c.filters)
      }
    end)
  end

  defp connection_type("STAGE"), do: API.Connection.Type.value(:TYPE_STAGE)
  defp connection_type("EVENT_SOURCE"), do: API.Connection.Type.value(:TYPE_EVENT_SOURCE)
  defp connection_type(_), do: API.Connection.Type.value(:TYPE_UNKNOWN)

  defp filter_operator("AND"), do: API.Connection.FilterOperator.value(:FILTER_OPERATOR_AND)
  defp filter_operator("OR"), do: API.Connection.FilterOperator.value(:FILTER_OPERATOR_OR)
  defp filter_operator(_), do: API.Connection.FilterOperator.value(:FILTER_OPERATOR_AND)

  defp connection_filters(filters) do
    Enum.map(filters, fn f ->
      %API.Connection.Filter{
        type: filter_type(f.type),
        data: filter_data(f.type, f)
      }
    end)
  end

  defp filter_type("DATA"), do: API.Connection.FilterType.value(:FILTER_TYPE_DATA)
  defp filter_type(_), do: API.Connection.FilterType.value(:FILTER_TYPE_UNKNOWN)

  defp filter_data("DATA", f) do
    %API.Connection.DataFilter{
      expression: f.data.expression
    }
  end

  defp filter_data(_, _), do: nil
end
