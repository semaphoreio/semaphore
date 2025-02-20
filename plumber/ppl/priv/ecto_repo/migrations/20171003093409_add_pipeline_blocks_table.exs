defmodule Ppl.EctoRepo.Migrations.AddPipelineBlocksTable do

  use Ecto.Migration

  def change do
    create table(:pipeline_blocks) do
      add :ppl_id, references(:pipeline_requests, type: :uuid), null: false
      add :name, :string, null: false
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :error_description, :text
      add :block_id, :uuid
      add :block_index, :integer, default: -1, null: false
      add :in_scheduling, :boolean, default: false
      add :recovery_count, :integer, default: 0, null: false
      add :terminate_request, :string
      add :terminate_request_desc, :string

      timestamps(type: :naive_datetime_usec)
    end

    create unique_index(:pipeline_blocks, [:ppl_id, :block_index],
                          name: :ppl_id_and_block_index_unique_index)

    create index(:pipeline_blocks, [:in_scheduling, :state, :updated_at])

    create unique_index(:pipeline_blocks, [:ppl_id, :name],
                          name: :ppl_id_and_name_unique_index)
  end
end
