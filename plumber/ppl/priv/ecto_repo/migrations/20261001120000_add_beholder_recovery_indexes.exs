defmodule Ppl.EctoRepo.Migrations.AddBeholderRecoveryIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(
      :after_ppl_tasks,
      [:updated_at],
      name: :after_ppl_tasks_in_scheduling_not_done_updated_at_index,
      concurrently: true,
      where: "in_scheduling AND state <> 'done'"
    )

    create_if_not_exists index(
      :time_limits,
      [:updated_at],
      name: :time_limits_in_scheduling_not_done_updated_at_index,
      concurrently: true,
      where: "in_scheduling AND state <> 'done'"
    )

    create_if_not_exists index(
      :pipeline_sub_inits,
      [:updated_at],
      name: :pipeline_sub_inits_in_scheduling_not_done_updated_at_index,
      concurrently: true,
      where: "in_scheduling AND state <> 'done'"
    )
  end
end
