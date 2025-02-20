defmodule Rbac.FrontRepo.Migrations.CreateOrganizationsTable do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :username, :string
      add :box_limit, :integer
      add :creator_id, :binary_id
      add :suspended, :boolean
      add :open_source, :boolean
      add :restricted, :boolean, default: false
      add :settings, :map
      add :verified, :boolean
      add :ip_allow_list, :string, null: false, default: ""
      add :allowed_id_providers, :string, null: false, default: ""
      add :deny_member_workflows, :boolean, null: false, default: false
      add :deny_non_member_workflows, :boolean, null: false, default: false

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end
  end
end
