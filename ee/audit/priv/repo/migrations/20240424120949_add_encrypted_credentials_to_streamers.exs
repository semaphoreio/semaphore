defmodule Audit.Repo.Migrations.AddEncryptedCredentialsToStreamers do
  use Ecto.Migration

  def change do
    alter table(:streamers) do
      add(:encrypted_credentials, :bytea, null: true, default: nil)
    end
  end
end
