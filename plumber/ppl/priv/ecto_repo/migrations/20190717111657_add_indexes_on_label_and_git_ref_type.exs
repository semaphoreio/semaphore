defmodule Ppl.EctoRepo.Migrations.AddIndexesOnLabelAndGitRefType do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:pipelines, [:label], concurrently: true)
    create index(:pipeline_requests, ["(source_args -> 'git_ref_type')"],
                  concurrently: true)
  end
end
