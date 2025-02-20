defmodule Block.EctoRepo.Migrations.AddBlocksTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :block_id, references(:block_requests, type: :uuid)
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :error_description, :text, default: ""
      add :in_scheduling, :boolean, default: false
      add :recovery_count, :integer, default: 0, null: false
      add :terminate_request, :string
      add :terminate_request_desc, :string

      timestamps(type: :naive_datetime_usec)
    end

    create index(:blocks, [:in_scheduling, :state, :updated_at])
    create unique_index(:blocks, [:block_id])
  end
end
