defmodule Ppl.EctoRepo.Migrations.AddPipelineRequestsOrganizationIdInsertedAtIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # ListRequesters filters by organization and an inserted_at window. Without
  # this index it scans every organization's requests inside the window.
  def change do
    create_if_not_exists index(
      :pipeline_requests,
      ["(request_args ->> 'organization_id')", :inserted_at],
      name: :pipeline_requests_organization_id_inserted_at_index,
      concurrently: true
    )
  end
end
