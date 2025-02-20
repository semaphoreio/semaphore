defmodule Ppl.EctoRepo.Migrations.AddNewQueueModel do
  use Ecto.Migration

  def change do
    create table(:queues, primary_key: false) do
      add :queue_id,            :uuid,        primary_key: true
      add :name,                :string
      add :user_generated,      :boolean,     default: false
      add :scope,               :string
      add :project_id,          :string
      add :organization_id,     :string

      timestamps(type: :naive_datetime_usec)
    end

    create unique_index(:queues, [:project_id, :name],
                         name: :unique_queue_name_for_project, where: "scope = 'project'")

    create unique_index(:queues, [:organization_id, :name],
                         name: :unique_queue_name_for_org, where: "scope = 'organization'")

    create index(:queues, [:project_id])
    create index(:queues, [:organization_id])

    alter table(:pipelines) do
      add :queue_id, :string
    end
  end
end
