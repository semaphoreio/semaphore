defmodule RepositoryHub.Repo.Migrations.AddUnmarkedUpdatedAtIndexToBuildStatusGuards do
  @moduledoc false
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:build_status_guards, [:updated_at],
        name: :build_status_guards_unmarked_updated_at_index,
        where: "has_check_run IS NOT TRUE",
        concurrently: true
      )
    )
  end
end
