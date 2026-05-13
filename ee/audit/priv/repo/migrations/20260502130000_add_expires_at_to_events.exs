defmodule Audit.Repo.Migrations.AddExpiresAtToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :expires_at, :utc_datetime
    end
  end
end
