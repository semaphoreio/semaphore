defmodule Ppl.EctoRepo.Migrations.AddDeletionRequestedToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :deletion_requested, :boolean, default: false
    end
    
    create index(:pipelines, [:project_id])
  end
end
