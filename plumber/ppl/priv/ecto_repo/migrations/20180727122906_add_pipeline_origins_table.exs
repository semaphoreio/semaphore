defmodule Ppl.EctoRepo.Migrations.AddPipelineOriginsTable do
  use Ecto.Migration

  def change do
    create table(:pipeline_origins) do
      add :ppl_id, references(:pipeline_requests, type: :uuid), null: false
      add :initial_request, :map
      add :initial_definition, :text

      timestamps(type: :naive_datetime_usec)
    end

    create unique_index(:pipeline_origins, [:ppl_id], name: :one_origin_per_ppl)
  end
end
