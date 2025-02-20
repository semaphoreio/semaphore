defmodule Ppl.EctoRepo.Migrations.AddLatestWorkflowsTable do
  use Ecto.Migration

  def change do
    create table(:latest_workflows) do
      add :organization_id, :string
      add :project_id, :string
      add :git_ref, :string
      add :git_ref_type, :string
      add :wf_id, :string
      add :wf_number, :integer

      timestamps(type: :naive_datetime_usec)
    end

    create index(:latest_workflows, [:organization_id])

    create unique_index(:latest_workflows, [:project_id, :git_ref_type, :git_ref],
                                          name: :one_wf_per_git_ref_on_project)
  end
end
