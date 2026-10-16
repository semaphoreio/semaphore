defmodule Ppl.EctoRepo.Migrations.AddTimeLimitsStateIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(
        :time_limits,
        [:state],
        name: :index_time_limits_on_state,
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(
        :time_limits,
        [:state],
        name: :index_time_limits_on_state,
        concurrently: true
      )
    )
  end
end
