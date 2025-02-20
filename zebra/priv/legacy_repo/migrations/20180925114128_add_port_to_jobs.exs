defmodule Zebra.Repo.Migrations.AddPortToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :port, :integer
    end
  end
end
