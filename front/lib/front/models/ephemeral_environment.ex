defmodule Front.Models.EphemeralEnvironment do
  @moduledoc """
  Model representing an Ephemeral Environment Type
  """

  require Logger

  alias InternalApi.EphemeralEnvironments.{EphemeralEnvironmentType, TypeState}

  @type state :: :unspecified | :draft | :ready | :cordoned | :deleted

  @type t :: %__MODULE__{
          id: String.t(),
          org_id: String.t(),
          name: String.t(),
          description: String.t(),
          created_by: String.t(),
          last_updated_by: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          state: state(),
          max_number_of_instances: integer()
        }

  defstruct [
    :id,
    :org_id,
    :name,
    :description,
    :created_by,
    :last_updated_by,
    :created_at,
    :updated_at,
    :state,
    :max_number_of_instances
  ]

  def list(org_id, project_id) do
    with {:ok, environment_types} <- Front.EphemeralEnvironments.list(org_id, project_id),
         environments <- Enum.map(environment_types, &from_proto/1) do
      {:ok, environments}
    else
      error ->
        Logger.error("Failed to list ephemeral environments: #{inspect(error)}")
        {:error, "Failed to list ephemeral environments"}
    end
  end

  def get(environment_id, org_id) do
    with {:ok, environment_type} <- Front.EphemeralEnvironments.describe(environment_id, org_id),
         environment <- from_proto(environment_type) do
      {:ok, environment}
    else
      error ->
        Logger.error("Failed to get ephemeral environment: #{inspect(error)}")
        {:error, "Failed to get ephemeral environment"}
    end
  end

  @spec create(any(), any(), any(), any(), any()) ::
          {:error, <<_::304>>} | {:ok, Front.Models.EphemeralEnvironment.t()}
  def create(org_id, name, description, user_id, max_instances) do
    environment_type = %EphemeralEnvironmentType{
      id: Ecto.UUID.generate(),
      org_id: org_id,
      name: name,
      description: description,
      created_by: user_id,
      last_updated_by: user_id,
      created_at: now_proto_timestamp(),
      updated_at: now_proto_timestamp(),
      state: TypeState.value(:TYPE_STATE_DRAFT),
      max_number_of_instances: max_instances
    }

    with {:ok, created_type} <- Front.EphemeralEnvironments.create(environment_type),
         environment <- from_proto(created_type) do
      {:ok, environment}
    else
      error ->
        Logger.error("Failed to create ephemeral environment: #{inspect(error)}")
        {:error, "Failed to create ephemeral environment"}
    end
  end

  def update(id, org_id, name, description, user_id, max_instances, state) do
    environment_type = %EphemeralEnvironmentType{
      id: id,
      org_id: org_id,
      name: name,
      description: description,
      last_updated_by: user_id,
      updated_at: now_proto_timestamp(),
      state: state,
      max_number_of_instances: max_instances
    }

    with {:ok, updated_type} <- Front.EphemeralEnvironments.update(environment_type),
         environment <- from_proto(updated_type) do
      {:ok, environment}
    else
      error ->
        Logger.error("Failed to update ephemeral environment: #{inspect(error)}")
        {:error, "Failed to update ephemeral environment"}
    end
  end

  def delete(id, org_id) do
    Front.EphemeralEnvironments.delete(id, org_id)
    |> case do
      :ok ->
        :ok

      error ->
        Logger.error("Failed to delete ephemeral environment: #{inspect(error)}")
        {:error, "Failed to delete ephemeral environment"}
    end
  end

  def cordon(id, org_id) do
    with {:ok, cordoned_type} <- Front.EphemeralEnvironments.cordon(id, org_id),
         environment <- from_proto(cordoned_type) do
      {:ok, environment}
    else
      error ->
        Logger.error("Failed to cordon ephemeral environment: #{inspect(error)}")
        {:error, "Failed to cordon ephemeral environment"}
    end
  end

  @doc """
  Creates a new EphemeralEnvironment struct from protobuf data
  """
  @spec from_proto(EphemeralEnvironmentType.t()) :: t
  def from_proto(proto) do
    %__MODULE__{
      id: proto.id,
      org_id: proto.org_id,
      name: proto.name,
      description: proto.description,
      created_by: proto.created_by,
      last_updated_by: proto.last_updated_by,
      created_at: timestamp_to_datetime(proto.created_at),
      updated_at: timestamp_to_datetime(proto.updated_at),
      state: parse_state(proto.state),
      max_number_of_instances: proto.max_number_of_instances
    }
  end

  @spec parse_state(integer()) :: state()
  defp parse_state(state_value) do
    state_value
    |> TypeState.key()
    |> case do
      :TYPE_STATE_DRAFT -> :draft
      :TYPE_STATE_READY -> :ready
      :TYPE_STATE_CORDONED -> :cordoned
      :TYPE_STATE_DELETED -> :deleted
      _ -> :unspecified
    end
  end

  @spec state_to_proto(state()) :: integer()
  def state_to_proto(state) do
    case state do
      :draft -> TypeState.value(:TYPE_STATE_DRAFT)
      :ready -> TypeState.value(:TYPE_STATE_READY)
      :cordoned -> TypeState.value(:TYPE_STATE_CORDONED)
      :deleted -> TypeState.value(:TYPE_STATE_DELETED)
      _ -> TypeState.value(:TYPE_STATE_UNSPECIFIED)
    end
  end

  defp timestamp_to_datetime(%Google.Protobuf.Timestamp{seconds: seconds}) do
    DateTime.from_unix!(seconds)
  end

  defp timestamp_to_datetime(_), do: DateTime.utc_now()

  defp now_proto_timestamp do
    seconds = DateTime.utc_now() |> DateTime.to_unix()
    Google.Protobuf.Timestamp.new(seconds: seconds)
  end
end
