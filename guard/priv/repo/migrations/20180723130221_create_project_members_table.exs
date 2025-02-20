defmodule Guard.Repo.Migrations.CreateProjectMembersTable do
  use Ecto.Migration

  def change do
    create table(:project_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, :binary_id
      add :user_id, :binary_id
    end

    create unique_index(:project_members, [:project_id, :user_id], name: :unique_member_in_project)
  end
end
