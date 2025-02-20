defmodule Ppl.EctoRepo.Migrations.AddTerminatedByToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :terminated_by, :string, default: ""
    end
  end
end
