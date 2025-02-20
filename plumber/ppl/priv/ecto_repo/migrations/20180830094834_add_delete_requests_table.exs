defmodule Ppl.EctoRepo.Migrations.AddDeleteRequestsTable do
  use Ecto.Migration

  def change do
    create table(:delete_requests) do
      add :project_id, :string, null: false
      add :requester, :string, null: false
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :in_scheduling, :boolean, default: false
      add :error_description, :text, default: ""
      add :recovery_count, :integer, default: 0, null: false

      timestamps(type: :naive_datetime_usec)
    end

    create index(:delete_requests, [:in_scheduling, :state, :updated_at])
    create index(:delete_requests, [:project_id])
  end
end
