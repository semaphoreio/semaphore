defmodule RepositoryHub.Repo.Migrations.AddHasCheckRunToBuildStatusGuards do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:build_status_guards) do
      add(:has_check_run, :boolean, null: true)
    end
  end
end
