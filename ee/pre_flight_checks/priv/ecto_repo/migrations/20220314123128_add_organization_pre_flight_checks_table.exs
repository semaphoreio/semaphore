defmodule PreFlightChecks.EctoRepo.Migrations.AddOrganizationPreFlightChecksTable do
  use Ecto.Migration

  def change do
    create table(:organization_pre_flight_checks) do
      add :organization_id, :string
      add :requester_id, :string
      add :definition, :map

      timestamps()
    end

    create unique_index(:organization_pre_flight_checks, [:organization_id],
             name: :unique_organization_pre_flight_checks
           )
  end
end
