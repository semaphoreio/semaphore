defmodule Rbac.Repo.Migrations.CreateUserGroupBindingTable do
  use Ecto.Migration

  def change do
    create table(:user_group_bindings, primary_key: false) do
      add :user_id, references(:rbac_users, on_delete: :delete_all), primary_key: true
      add :group_id, references(:groups, on_delete: :delete_all), primary_key: true
    end
  end
end
