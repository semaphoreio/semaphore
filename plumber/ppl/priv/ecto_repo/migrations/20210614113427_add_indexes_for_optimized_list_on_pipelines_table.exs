defmodule Ppl.EctoRepo.Migrations.AddIndexesForOptimizedListOnPipelinesTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(
      :pipelines,
      [:project_id, :branch_name, :inserted_at],
      concurrently: true
    )

    create index(
      :pipelines,
      [:project_id, :branch_name, :yml_file_path, :inserted_at],
      concurrently: true
    )
  end
end
