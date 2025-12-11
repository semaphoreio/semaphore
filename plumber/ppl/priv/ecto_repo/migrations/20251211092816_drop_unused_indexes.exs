defmodule Ppl.EctoRepo.Migrations.DropUnusedIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipelines_branch_inserted_at;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipelines_label_index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_request_args___requester_id__index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_source_args___git_ref_type__index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_pr_head_branch_yml_file_index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS latest_workflows_organization_id_index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_pr_head_branch_index;"
  end
end
