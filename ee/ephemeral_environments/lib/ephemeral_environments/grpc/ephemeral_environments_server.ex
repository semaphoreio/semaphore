defmodule EphemeralEnvironments.Grpc.EphemeralEnvironmentsServer do
  use GRPC.Server, service: InternalApi.EphemeralEnvironments.EphemeralEnvironments.Service

  alias EphemeralEnvironments.Service.EphemeralEnvironmentType

  def list(request, _stream) do
    {:ok, environment_types} = EphemeralEnvironmentType.list(request.org_id)
    %{environment_types: environment_types}
  end

  def describe(request, _stream) do
    case EphemeralEnvironmentType.describe(request.id, request.org_id) do
      {:ok, environment_type} ->
        # Note: instances field will be added once we implement instance management
        %{environment_type: environment_type, instances: []}

      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Environment type not found"

      {:error, error_message} ->
        raise GRPC.RPCError, status: :unknown, message: error_message
    end
  end

  def create(request, _stream) do
    case EphemeralEnvironmentType.create(request.environment_type) do
      {:ok, ret} ->
        %{environment_type: ret}

      {:error, error_message} ->
        raise GRPC.RPCError, status: :unknown, message: error_message
    end
  end

  def update(request, _stream) do
    case EphemeralEnvironmentType.update(request.environment_type) do
      {:ok, environment_type} ->
        %{environment_type: environment_type}

      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Environment type not found"

      {:error, error_message} ->
        raise GRPC.RPCError, status: :unknown, message: error_message
    end
  end

  def delete(_request, _stream) do
  end

  def cordon(_request, _stream) do
  end
end
