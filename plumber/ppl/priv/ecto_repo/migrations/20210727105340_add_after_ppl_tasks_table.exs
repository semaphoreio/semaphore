defmodule Ppl.EctoRepo.Migrations.AddAfterPplTasksTable do
  use Ecto.Migration

  def change do
    create table(:after_ppl_tasks) do
      add :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :delete_all), null: false
      add :after_task_id, :string
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :in_scheduling, :boolean, default: false
      add :error_description, :text, default: ""
      add :recovery_count, :integer, default: 0, null: false
      add :terminate_request, :string
      add :terminate_request_desc, :string
      timestamps(type: :naive_datetime_usec)
    end

    create index(:after_ppl_tasks, [:state, :in_scheduling, :updated_at])

    create unique_index(:after_ppl_tasks, [:ppl_id], name: :one_after_task_per_ppl)
  end
end
