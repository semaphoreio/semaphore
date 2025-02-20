defmodule Guard.FrontRepo.OrganizationContact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  alias InternalApi.Organization.OrganizationContact.ContactType

  schema "organization_contacts" do
    field(:contact_type, Ecto.Enum,
      values: [ContactType.key(1), ContactType.key(2), ContactType.key(3)]
    )

    field(:email, :string)
    field(:name, :string)
    field(:phone, :string)

    belongs_to(:organization, Guard.FrontRepo.Organization)
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:email, :name, :phone, :contact_type, :organization_id])
    |> validate_required([:contact_type, :organization_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  end
end
