defmodule Guard.FrontRepo.OrganizationSuspension do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  alias InternalApi.Organization.Suspension.Reason

  schema "organization_suspensions" do
    field(:reason, Ecto.Enum, values: [Reason.key(0), Reason.key(1), Reason.key(2)])

    field(:origin, :string)
    field(:description, :string)
    field(:deleted_at, :utc_datetime)

    belongs_to(:organization, Guard.FrontRepo.Organization)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(suspension, attrs) do
    suspension
    |> cast(attrs, [:reason, :origin, :description, :deleted_at, :organization_id])
    |> validate_required([:reason, :origin, :organization_id])
  end
end
