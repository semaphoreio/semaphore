defmodule Ppl.EctoRepo.Migrations.AddComplTaskIdToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipeline_sub_inits) do
      add :compile_task_id, :string
    end

    alter table(:pipelines) do
      add :compile_task_id, :string
    end
  end
end
