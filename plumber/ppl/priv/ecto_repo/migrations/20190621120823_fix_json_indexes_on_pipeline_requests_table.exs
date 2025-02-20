defmodule Ppl.EctoRepo.Migrations.FixJsonIndexesOnPipelineRequestsTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute "DROP INDEX IF EXISTS pipeline_requests_request_args___organization_id__index;"
    execute "DROP INDEX IF EXISTS pipeline_requests_request_args___requester_id__index;"

    create index(:pipeline_requests, ["(request_args -> 'organization_id')"],
                  concurrently: true, name: "pipeline_requests_request_args___organization_id__index")
    create index(:pipeline_requests, ["(request_args -> 'requester_id')"],
                  concurrently: true, name: "pipeline_requests_request_args___requester_id__index")
  end

  def down do
    execute "DROP INDEX IF EXISTS pipeline_requests_request_args___organization_id__index;"
    execute "DROP INDEX IF EXISTS pipeline_requests_request_args___requester_id__index;"

    create index(:pipeline_requests, ["(request_args -> 'organization_id')"],
                  concurrently: true, using: "GIN")
    create index(:pipeline_requests, ["(request_args -> 'requester_id')"],
                  concurrently: true, using: "GIN")
  end
end
