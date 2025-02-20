defmodule Guard.Repo.Migrations.AddUserIdToOktaTable do
  use Ecto.Migration

  def change do
    alter table(:okta_users) do
      add(:user_id, :uuid)
    end
  end
end
