defmodule EphemeralEnvironments.Service.EphemeralEnvironmentType do
  alias EphemeralEnvironments.Repo
  alias EphemeralEnvironments.Repo.EphemeralEnvironmentType, as: Schema

  @doc """
  Creates a new ephemeral environment type.

  ## Parameters
    - attrs: Map with keys:
      - org_id (required)
      - name (required)
      - created_by (required)
      - state (optional, defaults to :draft)
      - description (optional)
      - max_number_of_instances (optional)

  ## Returns
    - {:ok, %Schema{}} on success
    - {:error, String.t()} on validation failure
  """
  def create(attrs) do
    attrs = Map.put(attrs, :last_modified_by, attrs[:created_by])
    attrs = Map.put_new(attrs, :state, :draft)

    %Schema{}
    |> Schema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, record} -> {:ok, record}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
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
