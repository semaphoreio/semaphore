defmodule Audit.Repo.Migrations.DropCridentialsFromStreamingConfig do
  use Ecto.Migration

  def change do
    alter table(:streamers) do
      remove(:cridentials)
    end
  end
end
