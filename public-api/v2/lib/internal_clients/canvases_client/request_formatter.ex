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
end
