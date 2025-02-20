defmodule Audit.Repo.Migrations.AddMediumToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:medium, :integer, default: 0)
    end
  end
end
