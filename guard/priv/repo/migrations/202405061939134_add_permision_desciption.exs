defmodule Guard.Repo.Migrations.AddPermissionDescription do
  use Ecto.Migration

  def change do
    alter table(:permissions) do
      add_if_not_exists :description, :string, null: false, default: ""
    end
  end
end
