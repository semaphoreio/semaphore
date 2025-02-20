defmodule BranchHub.Model.Branches do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "branches" do
    field(:name, :string)
    field(:display_name, :string)
    field(:project_id, :binary_id)
    field(:pull_request_number, :integer)
    field(:pull_request_name, :string)
    field(:pull_request_mergeable, :boolean)
    field(:ref_type, :string)
    field(:archived_at, :utc_datetime)
    field(:used_at, :utc_datetime)

    timestamps(inserted_at_source: :created_at)
  end

  @required_fields ~w(name display_name project_id ref_type)a
  @optional_fields ~w(pull_request_number pull_request_name pull_request_mergeable archived_at used_at)a
  @ref_types ~w(pull-request tag branch)

  def changeset(branch, params \\ %{}) do
    branch
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:ref_type, @ref_types)
  end
end
