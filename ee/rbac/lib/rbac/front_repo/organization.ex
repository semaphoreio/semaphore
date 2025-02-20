defmodule Rbac.FrontRepo.Organization do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "organizations" do
    field(:name, :string)
    field(:username, :string)
    field(:creator_id, :binary_id)
    field(:suspended, :boolean)
    field(:open_source, :boolean)
    field(:verified, :boolean)
    field(:restricted, :boolean)
    field(:ip_allow_list, :string)
    field(:allowed_id_providers, :string)
    field(:deny_member_workflows, :boolean)
    field(:deny_non_member_workflows, :boolean)
    field(:settings, :map)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end
end
