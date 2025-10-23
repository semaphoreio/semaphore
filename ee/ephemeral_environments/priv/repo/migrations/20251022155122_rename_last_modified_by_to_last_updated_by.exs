defmodule EphemeralEnvironments.Repo.Migrations.RenameLastModifiedByToLastUpdatedBy do
  use Ecto.Migration

  def change do
    rename table(:ephemeral_environment_types), :last_modified_by, to: :last_updated_by
  end
end
