defmodule Zebra.LegacyRepo.Migrations.AddExecutionTimeLimitToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :execution_time_limit, :integer
    end
  end
end
