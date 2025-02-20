defmodule Block.EctoRepo.Migrations.AddBlockSubpplsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:block_subppls) do
      add :block_id, references(:block_requests, type: :uuid)
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :subppl_file_path, :string
      add :subppl_id, :uuid
      add :block_subppl_index, :integer, default: -1
      add :in_scheduling, :boolean, default: false
      add :recovery_count, :integer, default: 0, null: false
      add :terminate_request, :string
      add :terminate_request_desc, :string

      timestamps(type: :naive_datetime_usec)
    end

    create index(:block_subppls, [:in_scheduling, :state, :updated_at])
  end
end
