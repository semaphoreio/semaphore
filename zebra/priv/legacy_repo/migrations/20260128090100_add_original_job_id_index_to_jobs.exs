defmodule Zebra.LegacyRepo.Migrations.AddOriginalJobIdIndexToJobs do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create index(:jobs, [:original_job_id],
      name: "index_jobs_on_original_job_id_not_null",
      concurrently: true,
      where: "original_job_id IS NOT NULL",
      if_not_exists: true
    )
  end
end
