defmodule Ppl.EctoRepo.Migrations.AddParallelRunToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :parallel_run, :boolean
    end
  end
end
