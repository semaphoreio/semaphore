defmodule Ppl.EctoRepo.Migrations.AddExpiresAtMarkingIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(
      :pipeline_requests,
      ["(request_args->>'organization_id')", :inserted_at],
      name: :idx_pipeline_requests_retention_marking,
      concurrently: true,
      where: "expires_at IS NULL"
    )
  end
end
