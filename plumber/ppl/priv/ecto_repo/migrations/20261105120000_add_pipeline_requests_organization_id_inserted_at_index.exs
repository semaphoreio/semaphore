defmodule Ppl.EctoRepo.Migrations.AddPipelineRequestsOrganizationIdInsertedAtIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # ListRequesters filters by organization and an inserted_at window. Without
  # this index it scans every organization's requests inside the window.
  #
  # An interrupted concurrent build leaves an INVALID index behind, and
  # create_if_not_exists then skips it by name. Check
  #   SELECT indisvalid FROM pg_index
  #   WHERE indexrelid = 'pipeline_requests_organization_id_inserted_at_index'::regclass;
  # If it is false, DROP INDEX CONCURRENTLY pipeline_requests_organization_id_inserted_at_index and
  # recreate it by hand with the same CREATE INDEX CONCURRENTLY statement.
  # Running this migration again is a no-op once its version is recorded.
  def change do
    create_if_not_exists index(
      :pipeline_requests,
      ["(request_args ->> 'organization_id')", :inserted_at],
      name: :pipeline_requests_organization_id_inserted_at_index,
      concurrently: true
    )
  end
end
