defmodule Ppl.EctoRepo.Migrations.AddPrioritiesFieldsForPplAndBlk do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :priority, :integer
    end

    alter table(:pipeline_blocks) do
      add :priority, :integer
    end
  end
end
