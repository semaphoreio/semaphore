defmodule Guard.FrontRepo.Migrations.CreateProjectsTable do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :organization_id, :binary_id
      add :creator_id, :binary_id
    end
  end
end
