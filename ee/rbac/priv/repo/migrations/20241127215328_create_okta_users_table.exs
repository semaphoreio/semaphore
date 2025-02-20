defmodule Rbac.Repo.Migrations.CreateOktaUsersTable do
  use Ecto.Migration

  def change do
    create table("okta_users") do
      add(:integration_id, :binary_id, null: false)
      add(:org_id, :binary_id, null: false)
      add(:payload, :jsonb, null: false)
      add(:state, :string, null: false)
      add(:user_id, :uuid)
      add(:email, :string)

      timestamps()
    end

    create(index("okta_users", :integration_id))
    create(unique_index(:okta_users, [:integration_id, :email]))
  end
end
