defmodule Ppl.EctoRepo.Migrations.DropUnusedPrBranchIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_source_args_branch_name;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_source_args_pr_branch_name;"
  end
end
