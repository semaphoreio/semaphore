defmodule Guard.Repo.Migrations.CreateRoleInheritanceTable do
  use Ecto.Migration

  def change do
    create table(:role_inheritance,primary_key: false) do
      add :inheriting_role_id, references(:rbac_roles, on_delete: :delete_all), primary_key: true
      add :inherited_role_id, references(:rbac_roles, on_delete: :delete_all), primary_key: true
    end

    create constraint(:role_inheritance, :infinite_loop_constraint,
        check: "inherited_role_id != inheriting_role_id", comment: "Role can not inherit itself!")
  end
end
