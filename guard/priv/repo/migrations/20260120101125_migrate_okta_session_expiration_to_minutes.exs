defmodule Guard.Repo.Migrations.MigrateOktaSessionExpirationToMinutes do
  use Ecto.Migration

  def change do
    alter table(:okta_integrations) do
      add(:session_expiration_minutes, :integer, null: false, default: 20160) # 14 days
    end
  end
end
