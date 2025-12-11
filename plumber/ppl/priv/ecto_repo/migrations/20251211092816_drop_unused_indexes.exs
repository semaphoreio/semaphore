defmodule Ppl.EctoRepo.Migrations.DropUnusedIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipelines_branch_inserted_at;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipelines_label_index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_request_args___requester_id__index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_source_args___git_ref_type__index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_pr_head_branch_yml_file_index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS latest_workflows_organization_id_index;"
    execute "DROP INDEX CONCURRENTLY IF EXISTS pipeline_requests_pr_head_branch_index;"
  end

  def down do
    execute "CREATE INDEX CONCURRENTLY pipelines_branch_inserted_at ON pipelines (branch_name, inserted_at DESC);"
    execute "CREATE INDEX CONCURRENTLY pipelines_label_index ON pipelines (label);"
    execute "CREATE INDEX CONCURRENTLY pipeline_requests_request_args___requester_id__index ON pipeline_requests ((request_args -> 'requester_id'));"
    execute "CREATE INDEX CONCURRENTLY pipeline_requests_source_args___git_ref_type__index ON pipeline_requests ((source_args -> 'git_ref_type'));"
    execute "CREATE INDEX CONCURRENTLY pipeline_requests_pr_head_branch_yml_file_index ON pipeline_requests ((request_args ->> 'project_id'), (source_args ->> 'git_ref_type'), (source_args ->> 'pr_branch_name'), (request_args ->> 'working_dir'), (request_args ->> 'file_name'), inserted_at DESC, id DESC) WHERE source_args ->> 'git_ref_type' = 'pr';"
    execute "CREATE INDEX latest_workflows_organization_id_index ON latest_workflows (organization_id);"
    execute "CREATE INDEX CONCURRENTLY pipeline_requests_pr_head_branch_index ON pipeline_requests ((request_args ->> 'project_id'), (source_args ->> 'git_ref_type'), (source_args ->> 'pr_branch_name'), inserted_at DESC, id DESC) WHERE source_args ->> 'git_ref_type' = 'pr';"
  end
end
