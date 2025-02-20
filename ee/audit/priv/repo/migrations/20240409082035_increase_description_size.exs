defmodule Audit.Repo.Migrations.IncreaseDescriptionSize do
  use Ecto.Migration

  def change do
      alter table(:events) do
        modify(:description, :string, size: 500)
      end
  end
end
