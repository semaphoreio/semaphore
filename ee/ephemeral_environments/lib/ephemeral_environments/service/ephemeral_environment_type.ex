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
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
