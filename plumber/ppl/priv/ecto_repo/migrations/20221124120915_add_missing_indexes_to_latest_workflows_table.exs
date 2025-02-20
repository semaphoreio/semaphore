defmodule Ppl.EctoRepo.Migrations.AddMissingIndexesToLatestWorkflowsTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(
      :pipelines,
      [:branch_name, :updated_at, :id],
      name: "index_latest_workflows_on_project_id_updated_at_and_id",
      concurrently: true
    )
  end
end
