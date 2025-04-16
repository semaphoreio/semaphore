defmodule Projecthub.Repo.Migrations.AddDeletedAtForProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :deleted_at, :utc_datetime, null: true, default: nil
      add :deleted_by, :binary_id, null: true, default: nil
    end
  end
end
