defmodule Zebra.LegacyRepo.Migrations.CreateDebugs do
  use Ecto.Migration

  def change do
    create table(:debugs) do
      add :job_id, :binary_id
      add :debugged_id, :binary_id
      add :debugged_type, :string
    end

    create index(:debugs, [:job_id])
    create index(:debugs, [:debugged_type, :debugged_id])
  end
end
