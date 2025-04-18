defmodule InternalClients.Canvases.ResponseFormatter do
  @moduledoc """
  Module parses the response from canvas service
  """
  alias InternalApi.Delivery, as: API

  def process_response({:ok, r = %API.CreateCanvasResponse{}}) do
    {:ok, r.canvas}
  end

  def process_response({:ok, r = %API.DescribeCanvasResponse{}}) do
    {:ok, r.canvas}
  end

  def process_response({:ok, r = %API.CreateEventSourceResponse{}}) do
    {:ok, r.event_source}
  end

  def process_response({:ok, r = %API.DescribeEventSourceResponse{}}) do
    {:ok, r.event_source}
  end

  def process_response({:ok, r = %API.CreateStageResponse{}}) do
    {:ok, r.stage}
  end

  def process_response({:ok, r = %API.DescribeStageResponse{}}) do
    {:ok, r.stage}
  end

  def process_response({:ok, r = %API.ListStagesResponse{}}) do
    {:ok, r.stages}
  end

  def process_response({:ok, r = %API.ListEventSourcesResponse{}}) do
    {:ok, r.event_sources}
  end

  def process_response({:ok, r = %API.ListStageEventsResponse{}}) do
    {:ok, r.events}
  end

  def process_response({:ok, r = %API.ApproveStageEventResponse{}}) do
    {:ok, r.event}
  end

  @doc """
  Error responses are GRPC.RPCError structs. We pattern match on the status code and
  return a tuple with the error code and message.
  Status code is not an atom for this protobuf version, so we pattern match on the integer value as well.
  """
  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [5, :not_found] do
    {:error, {:not_found, message}}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [3, :invalid_argument] do
    {:error, {:user, message}}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [7, :internal] do
    {:error, {:internal, message}}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [2, :unknown] do
    PublicAPI.Util.Log.internal_error("Unknown response", "process_response", "Canvas")
    {:error, {:internal, message}}
  end

  def process_response(error), do: error
end
