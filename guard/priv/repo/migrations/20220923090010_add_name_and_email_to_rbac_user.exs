defmodule Guard.Repo.Migrations.AddNameAndEmailToRbacUser do
  use Ecto.Migration

  def change do
    alter table(:rbac_users) do
      add :email, :string
      add :name, :string

      timestamps(default: fragment("now()"))
    end

    create unique_index(:rbac_users, :email)
  end
end
