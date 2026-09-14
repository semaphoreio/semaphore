defmodule Audit.Repo.Migrations.AddExpiresAtToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add_if_not_exists :expires_at, :utc_datetime
    end
  end
end
