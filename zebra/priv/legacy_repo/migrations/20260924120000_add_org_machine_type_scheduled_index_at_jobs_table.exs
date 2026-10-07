defmodule Zebra.LegacyRepo.Migrations.AddOrgMachineTypeScheduledIndexAtJobsTable do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create_if_not_exists(
      index(:jobs, [:organization_id, :machine_type, :scheduled_at],
        name: "index_jobs_on_org_machine_type_scheduled_at_scheduled",
        concurrently: true,
        where: "aasm_state = 'scheduled'"
      )
    )
  end
end
