defmodule Guard.FrontRepo.Migrations.AddIndexesToOrganizations do
  use Ecto.Migration

  def change do
    create unique_index(:organizations, [:username], name: :index_organizations_on_username)
    create index(:organizations, [:creator_id], name: :index_organizations_on_creator_id)
  end
end
