defmodule Guard.FrontRepo.Migrations.AddDeactivatedAndDeactivatedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :deactivated, :boolean
      add :deactivated_at, :utc_datetime
    end
  end
end
