defmodule Ppl.EctoRepo.Migrations.AddExpiresAtDeletionIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(
      :pipeline_requests,
      [:expires_at],
      name: :idx_pipeline_requests_retention_deletion,
      concurrently: true,
      where: "expires_at IS NOT NULL"
    )
  end
end
