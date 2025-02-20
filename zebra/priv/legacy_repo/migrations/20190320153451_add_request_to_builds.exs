defmodule Zebra.LegacyRepo.Migrations.AddRequestToBuilds do
  use Ecto.Migration

  def change do
    alter table(:builds) do
      add :request, :map
    end
  end
end
