defmodule Ppl.EctoRepo.Migrations.AddPipelineTable do

  use Ecto.Migration

  def change do
    create table(:pipelines) do
      add :ppl_id, references(:pipeline_requests, type: :uuid), null: false
      add :name, :string
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :owner, :string
      add :repo_name, :string
      add :project_id, :string
      add :branch_name, :string
      add :yml_file_path, :string
      add :commit_sha, :string
      add :in_scheduling, :boolean, default: false
      add :error_description, :text, default: ""
      add :recovery_count, :integer, default: 0, null: false
      add :terminate_request, :string
      add :terminate_request_desc, :string

      timestamps(type: :naive_datetime_usec)
    end

    create index(:pipelines, [:in_scheduling, :state, :updated_at])

    create unique_index(:pipelines, [:ppl_id], name: :one_ppl_per_ppl_request)
  end
end
