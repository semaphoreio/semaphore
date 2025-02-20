defmodule Ppl.EctoRepo.Migrations.AddAfterPplTaskIdFields do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add(:after_task_id, :string)
      add(:with_after_task, :boolean)
    end
  end
end
