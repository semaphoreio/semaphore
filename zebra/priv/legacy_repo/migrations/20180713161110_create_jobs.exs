defmodule Zebra.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :build_id, :binary_id
      add :build_server_id, :binary_id
      add :organization_id, :binary_id

      add :aasm_state, :string
      add :result, :string
      add :name, :string
      add :index, :integer
      add :failure_reason, :string

      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
      add :enqueued_at, :utc_datetime
      add :scheduled_at, :utc_datetime
      add :started_at, :utc_datetime
      add :terminated_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :teardown_finished_at, :utc_datetime
    end

    create index(:jobs, [:aasm_state])
    create index(:jobs, [:result])
  end
end

