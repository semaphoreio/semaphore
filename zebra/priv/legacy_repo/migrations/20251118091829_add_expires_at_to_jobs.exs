defmodule Zebra.LegacyRepo.Migrations.AddExpiresAtToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :expires_at, :utc_datetime
    end
    create index(:jobs, [:expires_at, :created_at],
      name: "index_jobs_on_expires_created_not_null",
      concurrently: true,
      where: "expires_at IS NOT NULL"
    )
  end
end
