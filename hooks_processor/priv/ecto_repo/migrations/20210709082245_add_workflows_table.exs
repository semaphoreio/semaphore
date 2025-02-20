defmodule HooksProcessor.EctoRepo.Migrations.AddWorkflowsTable do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";")

    create table(:workflows, primary_key: false) do
      add :id,              :uuid,  default: fragment("uuid_generate_v4()"), primary_key: true
      add :project_id,      :uuid
      add :request,         :jsonb
      add :ppl_id,          :uuid
      add :result,          :string
      add :branch_id,       :uuid
      add :commit_sha,      :string
      add :git_ref,         :string
      add :state,           :string
      add :commit_author,   :string
      # new fields
      add :provider,        :string
      add :repository_id,   :uuid
      add :organization_id, :uuid
      add :received_at,     :utc_datetime_usec
      add :wf_id,           :uuid

      timestamps(inserted_at: :created_at, type: :naive_datetime_usec)
    end

    create index(:workflows, [:ppl_id])
    create index(:workflows, [:project_id])
    create index(:workflows, [:branch_id])
    create index(:workflows, [:state])
    #new indexes
    create unique_index(:workflows, [:repository_id, :received_at],
                        where: "repository_id IS NOT NULL",
                        name: :one_hook_received_at_per_repository)

    create index(:workflows, [:provider, :state, :created_at])
  end
end
