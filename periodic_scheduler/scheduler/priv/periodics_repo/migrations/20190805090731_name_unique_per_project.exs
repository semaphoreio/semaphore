defmodule Scheduler.PeriodicsRepo.Migrations.NameUniquePerProject do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    drop unique_index(:periodics, [:organization_id, :name],
                      name: :org_id_and_name_unique_index)

    create unique_index(:periodics, [:project_id, :name], concurrently: true,
                        name: :project_id_and_name_unique_index)
  end

  def down do
    drop unique_index(:periodics, [:project_id, :name],
                      name: :project_id_and_name_unique_index)

    create unique_index(:periodics, [:organization_id, :name], concurrently: true,
                        name: :org_id_and_name_unique_index)
  end
end
