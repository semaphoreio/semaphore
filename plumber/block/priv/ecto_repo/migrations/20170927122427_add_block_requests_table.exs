defmodule Block.EctoRepo.Migrations.AddBlockRequestsTable do
  @moduledoc """
  Creates table used for storing block requests data.
  - When block run is started, all passed ppl request data (service, repository name,
  owner, branch etc.) is stored in 'request_args' field, and block definition is
  stored in 'definition' field.
  - Field Ppl_request_id is pipeline request's identifier from Semaphore front.
  - Pipeline version is stored in 'version' field.
  - After refinment (cmd_file -> commands, build_matrix etc.), refined block
  definition is stored in 'build' field.
  - Field 'ppl_id' represents the id of pipeline to which the block belongs, and
  field 'pple_block_index' is index of this block in pipelines blocks list.
  - Field 'has_build?' serves as a flag wheter or not the block has build.
  - Field 'subppl_count' stores the number of subpipelines for that block
  """
  use Ecto.Migration

  def change do
    create table(:block_requests, primary_key: false) do
      add :id,      :uuid, primary_key: true
      add :version, :string
      add :definition, :map
      add :build, :map
      add :request_args, :map
      add :hook_id, :string, null: false
      add :ppl_id, :uuid, null: false
      add :pple_block_index, :integer,  null: false
      add :has_build?, :boolean
      add :subppl_count, :integer, default: 0

      timestamps(type: :naive_datetime_usec)
    end

    create unique_index(:block_requests, [:ppl_id, :pple_block_index],
                          name: :ppl_id_and_blk_ind_unique_index)
  end
end
