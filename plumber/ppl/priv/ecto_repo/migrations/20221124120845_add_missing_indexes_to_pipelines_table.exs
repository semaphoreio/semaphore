defmodule Ppl.EctoRepo.Migrations.AddMissingIndexesToPipelinesTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(
      :pipelines,
      [:branch_name, "inserted_at DESC"],
      name: "pipelines_branch_inserted_at",
      concurrently: true
    )
  end
end
