defmodule Rbac.Repo.Migrations.AddRbacUsersIndexes do
  use Ecto.Migration

  def change do
    alter table(:rbac_users) do
      add :user_id, references(:rbac_users, on_delete: :delete_all)
      add :group_id, references(:groups, on_delete: :delete_all)
    end
  end
end
