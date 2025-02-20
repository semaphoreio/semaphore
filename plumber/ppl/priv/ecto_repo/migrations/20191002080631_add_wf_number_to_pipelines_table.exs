defmodule Ppl.EctoRepo.Migrations.AddWfNumberToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :wf_number, :integer
    end
  end
end
