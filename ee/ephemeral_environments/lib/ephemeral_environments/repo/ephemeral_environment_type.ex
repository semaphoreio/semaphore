defmodule EphemeralEnvironments.Repo.EphemeralEnvironmentType do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ephemeral_environment_types" do
    field(:org_id, :binary_id)
    field(:name, :string)
    field(:description, :string)
    field(:created_by, :binary_id)
    field(:last_modified_by, :binary_id)
    field(:state, Ecto.Enum, values: [:draft, :ready, :cordoned, :deleted])
    field(:max_number_of_instances, :integer)

    timestamps()
  end

  def changeset(ephemeral_environment_type, attrs) do
    ephemeral_environment_type
    |> cast(attrs, [
      :org_id,
      :name,
      :description,
      :created_by,
      :last_modified_by,
      :state,
      :max_number_of_instances
    ])
    |> validate_required([:org_id, :name, :created_by, :last_modified_by, :state])
    |> validate_uuid(:org_id)
    |> validate_uuid(:created_by)
    |> validate_uuid(:last_modified_by)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_number(:max_number_of_instances, greater_than: 0)
  end

  defp validate_uuid(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      case Ecto.UUID.cast(value) do
        {:ok, _} -> []
        :error -> [{field, "must be a valid UUID"}]
      end
    end)
  end
end
