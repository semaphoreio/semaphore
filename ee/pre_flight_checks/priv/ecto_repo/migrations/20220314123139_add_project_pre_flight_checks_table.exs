defmodule PreFlightChecks.EctoRepo.Migrations.AddProjectPreFlightChecksTable do
  use Ecto.Migration

  def change do
    create table(:project_pre_flight_checks) do
      add :organization_id, :string
      add :project_id, :string
      add :requester_id, :string
      add :definition, :map

      timestamps()
    end

    create index(:project_pre_flight_checks, [:organization_id],
             name: :organizations_on_project_pre_flight_checks
           )

    create unique_index(:project_pre_flight_checks, [:project_id],
             name: :unique_project_pre_flight_checks
           )
  end
end
