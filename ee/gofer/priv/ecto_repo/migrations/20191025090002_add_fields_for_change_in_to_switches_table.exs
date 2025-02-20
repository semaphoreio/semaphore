defmodule Gofer.EctoRepo.Migrations.AddFieldsForChangeInToSwitchesTable do
  use Ecto.Migration

  def change do
    alter table(:switches) do
      add :project_id,  :string
      add :commit_sha, :string
      add :working_dir, :string
      add :commit_range, :string
    end
  end
end
