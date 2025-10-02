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

  def list(_request, _stream) do
    %ListResponse{}
  end

  def describe(_request, _stream) do
    %DescribeResponse{}
  end

  def create(request, _stream) do
    {:ok, ret} = EphemeralEnvironments.Service.EphemeralEnvironmentType.create(request.environment_type)
    converted = EphemeralEnvironments.Utils.Proto.from_map(%{environment_type: ret}, CreateResponse)
    converted
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
