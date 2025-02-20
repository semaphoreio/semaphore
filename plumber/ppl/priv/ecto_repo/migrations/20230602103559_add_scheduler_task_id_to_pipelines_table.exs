defmodule Ppl.EctoRepo.Migrations.AddSchedulerTaskIdToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add(:scheduler_task_id, :string)
    end
  end
end
