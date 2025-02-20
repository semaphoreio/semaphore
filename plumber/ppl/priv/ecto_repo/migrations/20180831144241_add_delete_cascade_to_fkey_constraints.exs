defmodule Ppl.EctoRepo.Migrations.AddDeleteCascadeToFkeyConstraints do
  use Ecto.Migration

  def up do
    # Ppls
    drop constraint(:pipelines, "pipelines_ppl_id_fkey")
    alter table(:pipelines) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :delete_all), null: false
    end
    
    # PplBlocks
    drop constraint(:pipeline_blocks, "pipeline_blocks_ppl_id_fkey")
    alter table(:pipeline_blocks) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :delete_all), null: false
    end
    
    # PplBlockConnections
    drop constraint(:pipeline_block_connections, "pipeline_block_connections_dependency_fkey")
    drop constraint(:pipeline_block_connections, "pipeline_block_connections_target_fkey")
    alter table(:pipeline_block_connections) do
      modify :target, references(:pipeline_blocks, on_delete: :delete_all), null: false
      modify :dependency, references(:pipeline_blocks, on_delete: :delete_all), null: false
    end
    
    # PplOrigins
    drop constraint(:pipeline_origins, "pipeline_origins_ppl_id_fkey")
    alter table(:pipeline_origins) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :delete_all), null: false
    end
    
    # PplSubInits
    drop constraint(:pipeline_sub_inits, "pipeline_sub_inits_ppl_id_fkey")
    alter table(:pipeline_sub_inits) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :delete_all), null: false
    end
    
    # PplTrace
    drop constraint(:pipeline_traces, "pipeline_traces_ppl_id_fkey")
    alter table(:pipeline_traces) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :delete_all), null: false
    end
  end

  def down do
    # Ppls
    drop constraint(:pipelines, "pipelines_ppl_id_fkey")
    alter table(:pipelines) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :nothing), null: false
    end
    
    # PplBlocks
    drop constraint(:pipeline_blocks, "pipeline_blocks_ppl_id_fkey")
    alter table(:pipeline_blocks) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :nothing), null: false
    end
    
    # PplBlockConnections
    drop constraint(:pipeline_block_connections, "pipeline_block_connections_dependency_fkey")
    drop constraint(:pipeline_block_connections, "pipeline_block_connections_target_fkey")
    alter table(:pipeline_block_connections) do
      modify :target, references(:pipeline_blocks, on_delete: :nothing), null: false
      modify :dependency, references(:pipeline_blocks, on_delete: :nothing), null: false
    end
    
    # PplOrigins
    drop constraint(:pipeline_origins, "pipeline_origins_ppl_id_fkey")
    alter table(:pipeline_origins) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :nothing), null: false
    end
    
    # PplSubInits
    drop constraint(:pipeline_sub_inits, "pipeline_sub_inits_ppl_id_fkey")
    alter table(:pipeline_sub_inits) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :nothing), null: false
    end
    
    # PplTrace
    drop constraint(:pipeline_traces, "pipeline_traces_ppl_id_fkey")
    alter table(:pipeline_traces) do
      modify :ppl_id, references(:pipeline_requests, type: :uuid, on_delete: :nothing), null: false
    end    
  end
end
