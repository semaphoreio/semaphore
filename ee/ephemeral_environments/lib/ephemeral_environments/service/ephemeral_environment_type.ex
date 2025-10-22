defmodule EphemeralEnvironments.Service.EphemeralEnvironmentType do
  import Ecto.Query
  alias EphemeralEnvironments.Repo
  alias EphemeralEnvironments.Repo.EphemeralEnvironmentType, as: Schema

  @doc """
  Lists all ephemeral environment types for a given organization.

  ## Parameters
    - org_id: String UUID of the organization

  ## Returns
    - {:ok, list of maps} on success
  """
  def list(org_id) when is_binary(org_id) do
    environment_types =
      Schema
      |> where([e], e.org_id == ^org_id)
      |> Repo.all()
      |> Enum.map(&struct_to_map/1)

    {:ok, environment_types}
  end

  @doc """
  Describes a specific ephemeral environment type by ID and org_id.

  ## Parameters
    - id: String UUID of the environment type
    - org_id: String UUID of the organization

  ## Returns
    - {:ok, map} on success
    - {:error, :not_found} if the environment type doesn't exist
  """
  def describe(id, org_id) when is_binary(id) and is_binary(org_id) do
    Schema
    |> where([e], e.id == ^id and e.org_id == ^org_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      record -> {:ok, struct_to_map(record)}
    end
  end

  @doc """
  Updates an existing ephemeral environment type.

  ## Parameters
    - attrs: Map with keys:
      - id (required)
      - org_id (required)
      - last_updated_by (required)
      - name (optional)
      - description (optional)
      - max_number_of_instances (optional)
      - state (optional)

  ## Returns
    - {:ok, map} on success
    - {:error, :not_found} if the environment type doesn't exist
    - {:error, String.t()} on validation failure
  """
  def update(attrs) do
    # Filter out proto default values that shouldn't be updated
    attrs = filter_proto_defaults(attrs)

    with {:ok, record} <- get_record(attrs[:id], attrs[:org_id]),
         {:ok, updated_record} <- update_record(record, attrs) do
      {:ok, struct_to_map(updated_record)}
    end
  end

  # Remove proto default values that indicate "not set" rather than explicit values
  defp filter_proto_defaults(attrs) do
    attrs
    |> Enum.reject(fn
      # Empty strings from proto mean "not set"
      {_key, ""} -> true
      # :unspecified enum means "not set"
      {:state, :unspecified} -> true
      # 0 for max_number_of_instances means "not set" (since validation requires > 0)
      {:max_number_of_instances, 0} -> true
      # Keep everything else
      _ -> false
    end)
    |> Map.new()
  end

  defp get_record(id, org_id) when is_binary(id) and is_binary(org_id) do
    Schema
    |> where([e], e.id == ^id and e.org_id == ^org_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  defp update_record(record, attrs) do
    record
    |> Schema.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_record} -> {:ok, updated_record}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  @doc """
  Creates a new ephemeral environment type.

  ## Parameters
    - attrs: Map with keys:
      - org_id (required)
      - name (required)
      - max_number_of_instances (required)
      - created_by (required)
      - description (optional)

  ## Returns
    - {:ok, map} on success
    - {:error, String.t()} on validation failure
  """
  def create(attrs) do
    attrs = Map.put(attrs, :last_updated_by, attrs[:created_by])
    attrs = Map.put(attrs, :state, :draft)

    %Schema{}
    |> Schema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, record} -> {:ok, struct_to_map(record)}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  ###
  ### Helper functions
  ###

  defp struct_to_map(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> rename_timestamp_fields()
  end

  # Rename Ecto's inserted_at to created_at to match proto definition
  defp rename_timestamp_fields(map) do
    map
    |> Map.put(:created_at, map[:inserted_at])
    |> Map.delete(:inserted_at)
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", safe_to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end

  # Safely convert values to strings, handling complex types
  defp safe_to_string(value) when is_binary(value), do: value
  defp safe_to_string(value) when is_atom(value), do: to_string(value)
  defp safe_to_string(value) when is_number(value), do: to_string(value)
  defp safe_to_string(value) when is_list(value), do: inspect(value)
  defp safe_to_string(value), do: inspect(value)
end
