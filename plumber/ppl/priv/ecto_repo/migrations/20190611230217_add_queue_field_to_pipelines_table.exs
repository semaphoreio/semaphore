defmodule Ppl.EctoRepo.Migrations.AddQueueFieldToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :queue, :string
    end
  end
end
