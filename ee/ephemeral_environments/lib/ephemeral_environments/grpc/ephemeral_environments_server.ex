defmodule EphemeralEnvironments.Grpc.EphemeralEnvironmentsServer do
  use GRPC.Server, service: InternalApi.EphemeralEnvironments.EphemeralEnvironments.Service

  alias InternalApi.EphemeralEnvironments.{
    ListRequest,
    ListResponse,
    DescribeRequest,
    DescribeResponse,
    CreateRequest,
    CreateResponse,
    UpdateRequest,
    UpdateResponse,
    DeleteRequest,
    DeleteResponse,
    CordonRequest,
    CordonResponse
  }

  def list(request, _stream) do
    case EphemeralEnvironments.Service.EphemeralEnvironmentType.list(request.org_id) do
      {:ok, environment_types} ->
        %{environment_types: environment_types}

      {:error, error_message} ->
        raise GRPC.RPCError, status: :unknown, message: error_message
    end
  end

  def describe(_request, _stream) do
    %DescribeResponse{}
  end

  def create(request, _stream) do
    case EphemeralEnvironments.Service.EphemeralEnvironmentType.create(request.environment_type) do
      {:ok, ret} ->
        %{environment_type: ret}

      {:error, error_message} ->
        raise GRPC.RPCError, status: :unknown, message: error_message
    end
  end

  def update(_request, _stream) do
    %UpdateResponse{}
  end

  def delete(_request, _stream) do
    %DeleteResponse{}
  end

  def cordon(_request, _stream) do
    %CordonResponse{}
  end
end
