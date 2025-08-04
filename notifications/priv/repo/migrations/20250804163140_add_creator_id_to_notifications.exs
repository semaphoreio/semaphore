defmodule Secrethub.Repo.Migrations.AddCreatorIdToNotifications do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :creator_id, :string, null: true
    end
  end
end
