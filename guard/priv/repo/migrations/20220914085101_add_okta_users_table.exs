defmodule Guard.Repo.Migrations.AddOktaUsersTable do
  use Ecto.Migration

  def change do
    create table("okta_users") do
      add(:integration_id, :binary_id, null: false)
      add(:org_id, :binary_id, null: false)
      add(:payload, :jsonb, null: false)
      add(:state, :string, null: false)

      timestamps()
    end

    create(index("okta_users", :integration_id))
  end
end
