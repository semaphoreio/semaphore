defmodule Ppl.EctoRepo.Migrations.AddIndexesForWfApi do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:pipeline_requests, ["(request_args -> 'organization_id')"],
                  concurrently: true, using: "GIN", name: "pipeline_requests_request_args___organization_id__index")
    create index(:pipeline_requests, ["(request_args -> 'requester_id')"],
                  concurrently: true, using: "GIN", name: "pipeline_requests_request_args___requester_id__index")
    create index(:pipeline_requests, [:wf_id], concurrently: true)
  end
end
