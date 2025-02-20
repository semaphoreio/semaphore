defmodule Audit.Repo.Migrations.AddDescription do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:description, :string)
    end
  end
end
