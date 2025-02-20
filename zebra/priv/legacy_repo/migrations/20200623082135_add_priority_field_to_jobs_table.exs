defmodule Zebra.LegacyRepo.Migrations.AddPriorityFieldToJobsTable do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :priority, :integer
    end
  end
end
