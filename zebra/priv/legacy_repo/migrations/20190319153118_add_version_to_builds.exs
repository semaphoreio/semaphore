defmodule Zebra.LegacyRepo.Migrations.AddVersionToBuilds do
  use Ecto.Migration

  def change do
    alter table(:builds) do
      add :version, :string
    end
  end
end
