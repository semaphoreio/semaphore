defmodule Ppl.EctoRepo.Migrations.AddDuplicateFieldToPipelineBlocksTable do
  use Ecto.Migration

  def change do
    alter table(:pipeline_blocks) do
      add :duplicate, :boolean, default: false
    end
  end
end
