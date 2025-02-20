defmodule Audit.Repo.Migrations.AddStreamEditData do
  use Ecto.Migration

  def change do
    alter table(:streamers) do
      add(:created_at, :utc_datetime)
      add(:updated_at, :utc_datetime)
      add(:activity_toggled_at, :utc_datetime)
      add(:updated_by, :binary_id)
      add(:activity_toggled_by, :binary_id)
    end
  end
end
