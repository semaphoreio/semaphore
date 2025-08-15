defmodule Notifications.Repo.Migrations.AddCreatorIdToNotifications do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :creator_id, :binary_id, null: true
    end
  end
end
