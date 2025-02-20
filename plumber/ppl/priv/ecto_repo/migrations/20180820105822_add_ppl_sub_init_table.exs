defmodule Ppl.EctoRepo.Migrations.AddPplSubInitTable do
  use Ecto.Migration

  def change do
    create table(:pipeline_sub_inits) do
      add :ppl_id, references(:pipeline_requests, type: :uuid), null: false
      add :init_type, :string, null: false
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

    create index(:pipeline_sub_inits, [:in_scheduling, :state, :updated_at])

    create unique_index(:pipeline_sub_inits, [:ppl_id], name: :one_ppl_sub_init_per_ppl_request)
  end
end
