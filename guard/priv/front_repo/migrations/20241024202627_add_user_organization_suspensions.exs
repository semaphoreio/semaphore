defmodule Guard.FrontRepo.Migrations.AddUserOrganizationSuspensions do
  use Ecto.Migration

  def change do
    create table(:organization_suspensions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :organization_id, references(:organizations, type: :uuid)
      add :reason, :string
      add :origin, :string
      add :description, :text
      add :deleted_at, :utc_datetime

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end

    create index(:organization_suspensions, [:organization_id], name: :index_organization_suspensions_on_organization_id)
  end
end
