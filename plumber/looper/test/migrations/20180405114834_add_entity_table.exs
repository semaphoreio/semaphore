defmodule Looper.Test.EctoRepo.Migrations.AddEntityTable do
  use Ecto.Migration

  def change do
    create table(:entities) do
      add :state, :string
      add :entity_id, :uuid

      timestamps(type: :utc_datetime_usec)
    end
  end
end
