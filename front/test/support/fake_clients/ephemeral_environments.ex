defmodule Support.FakeClients.EphemeralEnvironments do
  @moduledoc """
  Fake implementation of the EphemeralEnvironments client for testing purposes.
  This module uses an Agent to store ephemeral environment types in memory.
  It simulates the behaviour of the actual EphemeralEnvironments client.
  """
  use Agent
  @behaviour Front.EphemeralEnvironments.Behaviour

  alias InternalApi.EphemeralEnvironments.{EphemeralEnvironmentType, TypeState}

  @doc """
  Starts the fake ephemeral environments agent with empty state
  """
  def start_link(opts \\ []) do
    Agent.start_link(
      fn -> %{environment_types: %{}} end,
      Keyword.put_new(opts, :name, __MODULE__)
    )
  end

  @doc """
  Resets the agent state - useful for tests
  """
  def reset do
    Agent.update(__MODULE__, fn _ -> %{environment_types: %{}} end)
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def list(org_id, _project_id) do
    environment_types =
      Agent.get(__MODULE__, fn state ->
        state.environment_types
        |> Map.values()
        |> Enum.filter(&(&1.org_id == org_id))
        |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
      end)

    {:ok, environment_types}
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def create(environment_type) do
    cond do
      environment_type.name == "" ->
        {:error, "Environment type name cannot be empty"}

      String.length(environment_type.name) > 100 ->
        {:error, "Environment type name is too long (maximum 100 characters)"}

      true ->
        new_environment_type = %EphemeralEnvironmentType{
          environment_type
          | id: environment_type.id || Ecto.UUID.generate(),
            created_at: environment_type.created_at || now_proto_timestamp(),
            updated_at: environment_type.updated_at || now_proto_timestamp(),
            state: environment_type.state || TypeState.value(:TYPE_STATE_DRAFT)
        }

        Agent.update(__MODULE__, fn state ->
          put_in(state, [:environment_types, new_environment_type.id], new_environment_type)
        end)

        {:ok, new_environment_type}
    end
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def update(environment_type) do
    cond do
      environment_type.name == "" ->
        {:error, "Environment type name cannot be empty"}

      String.length(environment_type.name) > 100 ->
        {:error, "Environment type name is too long (maximum 100 characters)"}

      !valid_uuid?(environment_type.id) ->
        {:error, "Invalid environment type ID format"}

      true ->
        Agent.get_and_update(__MODULE__, fn state ->
          case get_in(state, [:environment_types, environment_type.id]) do
            nil ->
              {{:error, "Environment type not found"}, state}

            existing_type ->
              updated_type = %EphemeralEnvironmentType{
                environment_type
                | updated_at: now_proto_timestamp(),
                  created_at: existing_type.created_at
              }

              new_state = put_in(state, [:environment_types, environment_type.id], updated_type)

              {{:ok, updated_type}, new_state}
          end
        end)
    end
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def delete(id, org_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case get_in(state, [:environment_types, id]) do
        nil ->
          {{:error, "Environment type not found"}, state}

        environment_type ->
          if environment_type.org_id != org_id do
            {{:error, "Environment type does not belong to this organization"}, state}
          else
            # Mark as deleted instead of removing from storage
            deleted_type = %{environment_type | state: TypeState.value(:TYPE_STATE_DELETED)}
            new_state = put_in(state, [:environment_types, id], deleted_type)
            {:ok, new_state}
          end
      end
    end)
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def cordon(id, org_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case get_in(state, [:environment_types, id]) do
        nil ->
          {{:error, "Environment type not found"}, state}

        environment_type ->
          if environment_type.org_id != org_id do
            {{:error, "Environment type does not belong to this organization"}, state}
          else
            cordoned_type = %{
              environment_type
              | state: TypeState.value(:TYPE_STATE_CORDONED),
                updated_at: now_proto_timestamp()
            }

            new_state = put_in(state, [:environment_types, id], cordoned_type)
            {{:ok, cordoned_type}, new_state}
          end
      end
    end)
  end

  @doc """
  Helper function to add a test environment type directly
  """
  def add_test_environment_type(environment_type) do
    Agent.update(__MODULE__, fn state ->
      put_in(state, [:environment_types, environment_type.id], environment_type)
    end)
  end

  defp valid_uuid?(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp now_proto_timestamp do
    seconds = DateTime.utc_now() |> DateTime.to_unix()
    Google.Protobuf.Timestamp.new(seconds: seconds)
  end
end
