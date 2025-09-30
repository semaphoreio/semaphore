defmodule EphemeralEnvironments.Repo.EphemeralEnvironmentType do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ephemeral_environment_types" do
    field :org_id, :binary_id
    field :name, :string
    field :description, :string
    field :created_by, :binary_id
    field :last_modified_by, :binary_id
    field :state, :string
    field :max_number_of_instances, :integer

    timestamps()
  end

  @doc false
  def changeset(ephemeral_environment_type, attrs) do
    ephemeral_environment_type
    |> cast(attrs, [:org_id, :name, :description, :created_by, :last_modified_by, :state, :max_number_of_instances])
    |> validate_required([:org_id, :name, :created_by, :last_modified_by, :state])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:state, [:draft, :ready, :cordoned, :deleted])
    |> validate_number(:max_number_of_instances, greater_than: 0)
  end
end