defmodule Guard.FrontRepo.Migrations.AddBlockedAtToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :blocked_at, :utc_datetime
    end
  end
end
