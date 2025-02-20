defmodule Secrethub.Repo.Migrations.AddProjectsAllowed do
  use Ecto.Migration

  def change do
    alter table(:secrets) do
      add :all_projects, :boolean, null: false, default: true
      add :project_ids, {:array, :string}, null: false, default: []

      add(:used_at, :utc_datetime)
      add(:created_by, :string)
      add(:updated_by, :string)
      add(:used_by, :string)
    end
  end
end
