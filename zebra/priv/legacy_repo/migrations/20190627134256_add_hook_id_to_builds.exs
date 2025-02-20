defmodule Zebra.LegacyRepo.Migrations.AddHookIdToBuilds do
  use Ecto.Migration

  def change do
    alter table(:builds) do
      add :hook_id, :binary_id
    end
  end
end
