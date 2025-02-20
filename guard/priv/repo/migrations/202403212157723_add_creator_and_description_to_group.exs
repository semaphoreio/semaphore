defmodule Guard.Repo.Migrations.AddCreatorAndDecriptionToGroup do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      add_if_not_exists :creator_id, :binary_id, null: false
      add_if_not_exists :description, :string, null: false
    end
  end
end
