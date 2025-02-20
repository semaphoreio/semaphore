defmodule Ppl.EctoRepo.Migrations.RemoveOldQueueFieldFromPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      remove :queue
    end
  end
end
