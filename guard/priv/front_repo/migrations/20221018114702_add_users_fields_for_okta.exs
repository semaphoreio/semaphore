defmodule Guard.FrontRepo.Migrations.AddUsersFieldsForOkta do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :idempotency_token, :string
      add :single_org_user, :boolean
      add :creation_source, :string
      add :org_id, :uuid
    end

    create unique_index(:users, :idempotency_token, name: "users_idempotency_token_index", where: "idempotency_token IS NOT NULL")
  end
end
