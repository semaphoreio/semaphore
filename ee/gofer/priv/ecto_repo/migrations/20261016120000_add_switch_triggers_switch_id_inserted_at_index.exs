defmodule Gofer.EctoRepo.Migrations.AddSwitchTriggersSwitchIdInsertedAtIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists index(
                           :switch_triggers,
                           [:switch_id, :inserted_at],
                           name: :index_switch_triggers_on_switch_id_and_inserted_at,
                           concurrently: true
                         )
  end

  def down do
    drop_if_exists index(
                     :switch_triggers,
                     [:switch_id, :inserted_at],
                     name: :index_switch_triggers_on_switch_id_and_inserted_at,
                     concurrently: true
                   )
  end
end
