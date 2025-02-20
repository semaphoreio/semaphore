defmodule Ppl.EctoRepo.Migrations.AddInSchedulingIndexToTimeLimits do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(
      :time_limits,
      [:in_scheduling],
      name: "time_limits_in_scheduling_index",
      concurrently: true
    )
  end
end
