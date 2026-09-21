defmodule Zebra.LegacyRepo.Migrations.AddMachineTypeScheduledIndexAtJobsTable do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create index(:jobs, [:machine_type, :scheduled_at],
      name: "index_jobs_on_machine_type_scheduled_at_scheduled",
      concurrently: true,
      where: "aasm_state = 'scheduled'",
      if_not_exists: true
    )
  end
end
