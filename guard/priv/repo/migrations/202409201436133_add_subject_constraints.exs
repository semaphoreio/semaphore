defmodule Guard.Repo.Migrations.AddSubjectsConstraints do
  use Ecto.Migration

  def change do
    alter table(:subjects) do
      modify :name, :string, null: false
      modify :type, :string, null: false
    end
  end
end
