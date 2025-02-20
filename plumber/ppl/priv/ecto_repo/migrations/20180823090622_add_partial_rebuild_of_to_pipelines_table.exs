defmodule Ppl.EctoRepo.Migrations.AddPartialRebuildOfToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :partial_rebuild_of, :string, default: ""
    end
  end
end
