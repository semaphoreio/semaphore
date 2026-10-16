defmodule Ppl.EctoRepo.Migrations.AddPipelineRequestsExpiringOrgIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(
        :pipeline_requests,
        ["(request_args->>'organization_id')", :inserted_at],
        name: :index_pipeline_requests_on_org_and_inserted_at_expiring,
        concurrently: true,
        where: "expires_at IS NOT NULL"
      )
    )
  end

  def down do
    drop_if_exists(
      index(
        :pipeline_requests,
        ["(request_args->>'organization_id')", :inserted_at],
        name: :index_pipeline_requests_on_org_and_inserted_at_expiring,
        concurrently: true,
        where: "expires_at IS NOT NULL"
      )
    )
  end
end
