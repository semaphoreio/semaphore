defmodule Zebra.Repo.Migrations.AddSpecToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :spec, :map
    end
  end
end
