defmodule Ppl.EctoRepo.Migrations.AddTimeLimitsTable do
  use Ecto.Migration

  def change do
    create table(:time_limits) do
      add :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :delete_all), null: false
      add :deadline, :utc_datetime_usec
      add :type, :string
      add :block_index, :integer, default: -1
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :in_scheduling, :boolean, default: false
      add :error_description, :text, default: ""
      add :recovery_count, :integer, default: 0, null: false
      add :terminate_request, :string
      add :terminate_request_desc, :string

      timestamps(type: :naive_datetime_usec)
    end

    create index(:time_limits, [:type, :state, :deadline, :in_scheduling, :updated_at])

    create unique_index(:time_limits, [:ppl_id, :block_index], name: :one_limit_per_ppl_or_block)
  end
end
