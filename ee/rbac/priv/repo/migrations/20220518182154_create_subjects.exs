defmodule Rbac.Repo.Migrations.CreateSubjects do
  use Ecto.Migration

  def change do
    create table(:subjects) do
      add :name, :string, null: false
      add :type, :string, null: false
      timestamps(defaut: fragment("now()"))
    end
  end
end
