defmodule Guard.Repo.Migrations.RemoveGroupName do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      remove_if_exists :group_name, :string
    end
  end
end
