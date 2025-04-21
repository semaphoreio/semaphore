defmodule CanvasFront.Stores.Canvas do
  @moduledoc """
  GRPC-backed store for canvases.
  Fetches and saves canvases using InternalApi.Delivery.Delivery.Stub.
  """

  alias InternalApi.Delivery.{
    Delivery,
    Delivery.Stub,
    ListStagesRequest,
    ListStagesResponse,
    DescribeCanvasRequest,
    DescribeCanvasResponse,
    CreateCanvasRequest,
    CreateCanvasResponse,
    Canvas
  }

  require Logger

  defp grpc_channel do
    GRPC.Stub.connect(Application.fetch_env!(:canvas_front, :delivery_grpc_endpoint))
  end

  @doc "Get a canvas by id. Returns nil if not found."
  def get(params) do
    org_id = Map.get(params, :organization_id, "")

    req = %DescribeCanvasRequest{
      id: Map.get(params, :id),
      name: Map.get(params, :name),
      organization_id: org_id
    }

    with {:ok, channel} <- grpc_channel(),
         {:ok, %DescribeCanvasResponse{canvas: canvas}} <- Stub.describe_canvas(channel, req) do
      Logger.info("Canvas found: #{inspect(canvas)}")
      Map.from_struct(canvas)
    else
      e ->
        Logger.error("Failed to describe canvas: #{inspect(e)}")
        nil
    end
  end

  @doc "Create a new canvas. Returns created canvas or nil."
  def create(params) do
    org_id = Map.get(params, :organization_id, "")
    requester_id = Map.get(params, :requester_id, "")

    req = %CreateCanvasRequest{
      name: Map.get(params, :name),
      organization_id: org_id,
      requester_id: requester_id
    }

    with {:ok, channel} <- grpc_channel(),
         {:ok, %CreateCanvasResponse{canvas: canvas}} <- Stub.create_canvas(channel, req) do
      Map.from_struct(canvas)
    else
      e ->
        Logger.error("Failed to create canvas: #{inspect(e)}")
        nil
    end
  end
end
