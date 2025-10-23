defmodule Guard.FrontRepo.Migrations.AddDeletedAtForOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :deleted_at, :utc_datetime, null: true, default: nil
    end
  end
end
