defmodule Zebra.LegacyRepo.Migrations.CreateProjectsTableForTests do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE IF NOT EXISTS projects (
      id uuid PRIMARY KEY,
      artifact_store_id uuid
    )
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS projects"
  end
end
