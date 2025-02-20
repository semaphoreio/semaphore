defmodule RepositoryHub.Repo.Migrations.AddProjectsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :uuid, default: fragment("uuid_generate_v4()"), primary_key: true
    end
  end
end
