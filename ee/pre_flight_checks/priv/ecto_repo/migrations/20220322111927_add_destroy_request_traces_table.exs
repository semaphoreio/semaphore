defmodule PreFlightChecks.EctoRepo.Migrations.AddDestroyRequestTracesTable do
  use Ecto.Migration

  def change do
    create table(:destroy_request_traces) do
      add :organization_id, :string
      add :project_id, :string
      add :requester_id, :string
      add :level, :integer
      add :status, :integer

      timestamps()
    end

    create index(:destroy_request_traces, [:organization_id],
             name: :organization_id_destroy_request_traces
           )

    create index(:destroy_request_traces, [:project_id], name: :project_id_destroy_request_traces)
  end
end
