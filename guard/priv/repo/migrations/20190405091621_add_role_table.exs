defmodule Guard.Repo.Migrations.AddRoleTable do
  use Ecto.Migration

  def change do
    create table(:roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id
      add :org_id, :binary_id
      add :name, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index("roles", [:name, :user_id, :org_id], unique: true, name: :uniq_role_for_user_in_org)
  end
end
