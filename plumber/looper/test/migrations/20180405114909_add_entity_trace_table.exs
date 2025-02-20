defmodule Looper.Test.EctoRepo.Migrations.AddEntityTraceTable do
  use Ecto.Migration

  def change do
    create table(:entity_traces) do
      add :entity_id, :uuid
      add :created_at, :utc_datetime_usec
      add :pending_at, :utc_datetime_usec
      add :queuing_at, :utc_datetime_usec
      add :running_at, :utc_datetime_usec
      add :stopping_at, :utc_datetime_usec
      add :done_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end
  end
end
