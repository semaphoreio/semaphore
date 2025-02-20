defmodule Projecthub.Repo.Migrations.AddPublicFieldToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :public, :boolean, null: false, default: false
    end
  end
end
