defmodule Ppl.EctoRepo.Migrations.PipelineBlockConnections do
  use Ecto.Migration

  def change do
    create table(:pipeline_block_connections) do
      add :target, references(:pipeline_blocks), null: false
      add :dependency, references(:pipeline_blocks), null: false
    end

    create unique_index(:pipeline_block_connections, [:target, :dependency])

  end
end
