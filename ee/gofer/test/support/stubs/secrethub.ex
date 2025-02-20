defmodule Support.Stubs.Secrethub do
  alias Support.Stubs.Secrethub, as: Stub
  import ExUnit.Callbacks
  use Agent

  @mock SecrethubMock

  defmodule State do
    defstruct [:id, :name, :content, :action, :metadata]
  end

  def setup() do
    start_supervised!(__MODULE__)
    Stub.Grpc.init(@mock)
    :ok
  end

  def start_link(_args) do
    Agent.start_link(fn -> %Stub.State{} end, name: __MODULE__)
  end

  def set_state(params) do
    Agent.update(__MODULE__, fn _state -> struct(State, params) end)
  end

  def get_state() do
    Agent.get(__MODULE__, fn state -> Map.from_struct(state) end)
  end

  defmodule Grpc do
    alias InternalApi.Secrethub, as: API
    alias Support.Stubs.Secrethub, as: Stub

    @metadata_fields ~w(api_version kind req_id org_id user_id)a
    @mock_name SecrethubMock

    def init(mock) do
      GrpcMock.stub(mock, :create_encrypted, &__MODULE__.create/2)
      GrpcMock.stub(mock, :update_encrypted, &__MODULE__.update/2)
      GrpcMock.stub(mock, :destroy, &__MODULE__.destroy/2)
    end

    def expect(function, callback) do
      GrpcMock.stub(@mock_name, function, fn _request, _stream ->
        callback.()
      end)

      ExUnit.Callbacks.on_exit(fn ->
        __MODULE__.init(@mock_name)
      end)
    end

    def create(request = %API.CreateEncryptedRequest{}, _stream) do
      {id, name} =
        create_secret(agent_for(request), name(request), content(request), request.metadata)

      API.CreateEncryptedResponse.new(
        metadata: response_meta(request.metadata, ok_status()),
        secret: put_id_and_name(request.secret, id, name),
        encrypted_data: request.encrypted_data
      )
    end

    def update(request = %API.UpdateEncryptedRequest{}, _stream) do
      {id, name} =
        update_secret(agent_for(request), name(request), content(request), request.metadata)

      metadata = response_meta(request.metadata, ok_status())

      API.UpdateEncryptedResponse.new(
        metadata: metadata,
        secret: put_id_and_name(request.secret, id, name),
        encrypted_data: request.encrypted_data
      )
    end

    def destroy(request = %API.DestroyRequest{}, _stream) do
      delete_secret(agent_for(request), request.id, request.name, request.metadata)
      API.DestroyResponse.new(metadata: response_meta(request.metadata, ok_status()))
    end

    defp create_secret(agent, name, content, metadata) do
      Agent.get_and_update(agent, fn _state ->
        new_state = %Stub.State{
          id: UUID.uuid4(),
          name: name,
          content: content,
          action: :create,
          metadata: Map.from_struct(metadata)
        }

        {{new_state.id, new_state.name}, new_state}
      end)
    end

    defp update_secret(agent, name, content, metadata) do
      Agent.get_and_update(agent, fn state ->
        new_state = %Stub.State{
          state
          | name: name,
            content: content,
            action: :update,
            metadata: Map.from_struct(metadata)
        }

        {{state.id, state.name}, new_state}
      end)
    end

    defp delete_secret(agent, id, name, metadata) do
      Agent.get_and_update(agent, fn _state ->
        new_state = %Stub.State{
          id: id,
          name: name,
          action: :delete,
          metadata: Map.from_struct(metadata)
        }

        {{new_state.id, new_state.name}, new_state}
      end)
    end

    defp agent_for(_request), do: Stub
    defp ok_status, do: API.ResponseMeta.Status.new(code: :OK)
    defp name(request), do: request.secret.metadata.name
    defp content(request), do: request.encrypted_data

    defp put_id_and_name(secret, id, name) do
      metadata = %API.Secret.Metadata{secret.metadata | id: id, name: name}
      %API.Secret{secret | metadata: metadata}
    end

    defp response_meta(metadata = %API.RequestMeta{}, status),
      do:
        metadata
        |> Map.take(@metadata_fields)
        |> Map.put(:status, status)
        |> Enum.to_list()
        |> API.ResponseMeta.new()
  end
end
