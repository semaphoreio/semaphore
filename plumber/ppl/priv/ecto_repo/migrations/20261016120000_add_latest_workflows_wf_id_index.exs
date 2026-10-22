defmodule Ppl.EctoRepo.Migrations.AddLatestWorkflowsWfIdIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(
        :latest_workflows,
        [:wf_id],
        name: :index_latest_workflows_on_wf_id,
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(
        :latest_workflows,
        [:wf_id],
        name: :index_latest_workflows_on_wf_id,
        concurrently: true
      )
    )
  end
end
