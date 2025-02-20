defmodule Scheduler.PeriodicsRepo.Migrations.AddPeriodicsTable do
  use Ecto.Migration

  def change do
    create table(:periodics, primary_key: false) do
      add :id,              :uuid,   primary_key: true
      add :requester_id,    :string
      add :organization_id, :string
      add :name,            :string
      add :project_name,    :string
      add :project_id,      :string
      add :branch,          :string
      add :at,              :string
      add :pipeline_file,   :string


      timestamps()
    end

    create unique_index(:periodics, [:organization_id, :name],
                          name: :org_id_and_name_unique_index)
  end
end
