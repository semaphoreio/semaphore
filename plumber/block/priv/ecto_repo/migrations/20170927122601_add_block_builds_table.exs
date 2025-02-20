defmodule Block.EctoRepo.Migrations.AddBlockBuildsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:block_builds) do
      add :block_id, references(:block_requests, type: :uuid)
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :executable_id, :uuid
      add :description, :map
      add :in_scheduling, :boolean, default: false
      add :recovery_count, :integer, default: 0, null: false
      add :terminate_request, :string
      add :terminate_request_desc, :string

      timestamps(type: :naive_datetime_usec)
    end

    create index(:block_builds, [:in_scheduling, :state, :updated_at])
  end
end
