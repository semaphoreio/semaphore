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
       name: from_params(params, :name),
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
       name: from_params(params, :name),
       canvas_id: from_params!(params, :canvas_id),
       organization_id: from_params!(params, :organization_id),
       requester_id: from_params!(params, :user_id),
       approval_required: from_params(params, :approval_required),
       connections: from_params(params, :connections),
       run_template: from_params(params, :run_template)
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
end
