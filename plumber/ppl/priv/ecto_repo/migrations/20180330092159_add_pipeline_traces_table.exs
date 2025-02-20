defmodule Ppl.EctoRepo.Migrations.AddPipelineTracesTable do
  use Ecto.Migration

  def change do
    create table(:pipeline_traces) do
      add :ppl_id, references(:pipeline_requests, type: :uuid), null: false
      add :created_at, :utc_datetime_usec
      add :pending_at, :utc_datetime_usec
      add :queuing_at, :utc_datetime_usec
      add :running_at, :utc_datetime_usec
      add :stopping_at, :utc_datetime_usec
      add :done_at, :utc_datetime_usec

      timestamps(type: :naive_datetime_usec)
    end

    create unique_index(:pipeline_traces, [:ppl_id], name: :one_ppl_trace_per_ppl)
  end
end
