defmodule Zebra.LegacyRepo.Migrations.AddJobsUnfinishedBuildIdIndex do
  use Ecto.Migration

  #
  # Test copy of github_hooks/db/migrate/20261104120000_add_jobs_unfinished_build_id_index.rb,
  # which is what migrates the jobs table in production. Keep them identical.
  #

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(:jobs, [:build_id],
        name: :index_jobs_on_build_id_unfinished,
        where: "aasm_state <> 'finished'",
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(:jobs, [:build_id],
        name: :index_jobs_on_build_id_unfinished,
        concurrently: true
      )
    )
  end
end
