defmodule CanvasFront.Stores.EventSource do
  @moduledoc """
  GRPC-backed store for event sources.
  Fetches and saves event sources using InternalApi.Delivery.Delivery.Stub.
  """

  alias InternalApi.Delivery.{
    Delivery.Stub,
    ListEventSourcesRequest,
    ListEventSourcesResponse,
    DescribeEventSourceRequest,
    DescribeEventSourceResponse,
    CreateEventSourceRequest,
    CreateEventSourceResponse
    # EventSource
  }

  defp grpc_channel do
    GRPC.Stub.connect(Application.fetch_env!(:canvas_front, :delivery_grpc_endpoint))
  end

  @doc "List event sources for a canvas."
  def list(params) do
    org_id = Map.get(params, :organization_id, "")
    canvas_id = Map.get(params, :canvas_id, "")
    req = %ListEventSourcesRequest{organization_id: org_id, canvas_id: canvas_id}

    with {:ok, channel} <- grpc_channel(),
         {:ok, %ListEventSourcesResponse{event_sources: sources}} <-
           Stub.list_event_sources(channel, req) do
      Enum.map(sources, &Map.from_struct/1)
    else
      _ -> []
    end
  end

  @doc "Get a specific event source by id."
  def get(params) do
    org_id = Map.get(params, :organization_id, "")
    id = Map.get(params, :id)
    name = Map.get(params, :name)
    canvas_id = Map.get(params, :canvas_id, "")

    req = %DescribeEventSourceRequest{
      id: id,
      name: name,
      canvas_id: canvas_id,
      organization_id: org_id
    }

    with {:ok, channel} <- grpc_channel(),
         {:ok, %DescribeEventSourceResponse{event_source: source}} <-
           Stub.describe_event_source(channel, req) do
      Map.from_struct(source)
    else
      _ -> nil
    end
  end

  @doc "Create a new event source."
  def create(params) do
    org_id = Map.get(params, :organization_id, "")
    canvas_id = Map.get(params, :canvas_id, "")
    requester_id = Map.get(params, :requester_id, "")

    req = %CreateEventSourceRequest{
      name: Map.get(params, :name),
      organization_id: org_id,
      canvas_id: canvas_id,
      requester_id: requester_id
    }

    with {:ok, channel} <- grpc_channel(),
         {:ok, %CreateEventSourceResponse{event_source: source}} <-
           Stub.create_event_source(channel, req) do
      Map.from_struct(source)
    else
      _ -> nil
    end
  end
end
