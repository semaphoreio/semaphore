defmodule Zebra.LegacyRepo.Migrations.IntroduceJobStopRequestTable do
  use Ecto.Migration

  def change do
    create table(:job_stop_requests) do
      add :job_id, :binary_id, null: false
      add :build_id, :binary_id, null: false

      add :state, :string, null: false
      add :result, :string
      add :result_reason, :string

      add :created_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
      add :done_at, :utc_datetime
    end

    create index(:job_stop_requests, [:build_id])
    create unique_index(:job_stop_requests, [:job_id])
  end
end
