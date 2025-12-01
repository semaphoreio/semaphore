defmodule Zebra.LegacyRepo.Migrations.AddExpiresAtToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :expires_at, :utc_datetime
    end
  end
end
