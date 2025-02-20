defmodule Guard.FrontRepo.Migrations.AddRememberCreatedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :remember_created_at, :utc_datetime
    end
  end
end
