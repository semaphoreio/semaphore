defmodule Guard.FrontRepo.Migrations.CreateFederatedIdentitySyncRequests do
  use Ecto.Migration

  def change do
    create table(:federated_identity_sync_requests, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:repo_host, :string, null: false)
      add(:uid, :string, null: false)
      add(:claiming_user_id, :binary_id, null: false)
      add(:released_user_ids, {:array, :binary_id}, null: false, default: [])
      add(:login, :string, null: false)
      add(:attempts, :integer, null: false, default: 0)
      add(:last_error, :text)
      add(:next_attempt_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:federated_identity_sync_requests, [:next_attempt_at]))
    create(index(:federated_identity_sync_requests, [:repo_host, :uid]))
  end
end
