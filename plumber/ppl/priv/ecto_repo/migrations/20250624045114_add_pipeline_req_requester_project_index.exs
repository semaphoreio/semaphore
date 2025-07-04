defmodule Ppl.EctoRepo.Migrations.AddPipelineReqRequesterProjectIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(
        :pipeline_requests,
        [
          "(request_args ->> 'requester_id')",
          "(request_args ->> 'project_id')",
          "inserted_at DESC",
          "id DESC"
        ],
        where: "initial_request = true",
        name: "pipeline_requests_requester_project_inserted_at_id",
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(
        :pipeline_requests,
        [
          "(request_args ->> 'requester_id')",
          "(request_args ->> 'project_id')",
          "inserted_at DESC",
          "id DESC"
        ],
        where: "initial_request = true",
        name: "pipeline_requests_requester_project_inserted_at_id",
        concurrently: true
      )
    )
  end
end
