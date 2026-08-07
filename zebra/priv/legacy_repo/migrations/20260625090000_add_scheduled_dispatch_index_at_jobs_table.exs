defmodule Zebra.LegacyRepo.Migrations.AddScheduledDispatchIndexAtJobsTable do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create_if_not_exists(
      index(:jobs, [:machine_type, :organization_id, :machine_os_image, :scheduled_at],
        name: "index_jobs_on_machine_type_org_image_when_scheduled",
        concurrently: true,
        where: "aasm_state = 'scheduled'"
      )
    )
  end
end
