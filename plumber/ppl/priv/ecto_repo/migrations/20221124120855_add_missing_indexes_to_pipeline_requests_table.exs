defmodule Ppl.EctoRepo.Migrations.AddMissingIndexesToPipelineRequestsTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :pipeline_requests,
        [
          "(request_args ->> 'project_id')",
          "(request_args ->> 'branch_name')",
          "inserted_at DESC",
          "id DESC"
        ],
        where: "initial_request = true",
        name: "pipeline_requests_project_id_branch_name_inserted_at_id",
        concurrently: true
      )
    )

    create(
      index(
        :pipeline_requests,
        [
          "(request_args ->> 'organization_id')",
          "inserted_at DESC",
          "id DESC"
        ],
        where: "initial_request = true",
        name: "pipeline_requests_organization_id_inserted_at_id",
        concurrently: true
      )
    )

    create(
      index(
        :pipeline_requests,
        [
          "(request_args ->> 'project_id')",
          "inserted_at DESC",
          "id DESC"
        ],
        where: "initial_request = true",
        name: "pipeline_requests_project_id_inserted_at_id",
        concurrently: true
      )
    )
  end
end
