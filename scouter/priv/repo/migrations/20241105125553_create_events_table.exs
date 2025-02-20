defmodule Scouter.Repo.Migrations.CreateEventsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:events) do
      add(:organization_id, :string, null: false, default: "")
      add(:project_id, :string, null: false, default: "")
      add(:user_id, :string, null: false, default: "")

      add(:event_id, :string, null: false)

      timestamps()
    end

    create(
      unique_index(:events, [
        :organization_id,
        :project_id,
        :user_id,
        :event_id
      ])
    )

    create(index(:events, [:organization_id, :project_id, :user_id]))

    create(
      index(:events, [:organization_id, :user_id],
        where: "organization_id IS NOT NULL and project_id IS NOT NULL"
      )
    )

    create(index(:events, [:organization_id]))
    create(index(:events, [:user_id]))
  end
end
