defmodule Guard.FrontRepo.Migrations.AddVisitedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :visited_at, :utc_datetime
    end
  end
end
