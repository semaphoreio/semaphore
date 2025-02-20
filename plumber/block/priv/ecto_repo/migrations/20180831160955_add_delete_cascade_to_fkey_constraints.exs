defmodule Block.EctoRepo.Migrations.AddDeleteCascadeToFkeyConstraints do
  use Ecto.Migration

  def up do
    # Blocks
    drop constraint(:blocks, "blocks_block_id_fkey")
    alter table(:blocks) do
      modify :block_id, references(:block_requests, type: :uuid, on_delete: :delete_all), null: false
    end
    
    # BlockBuilds
    drop constraint(:block_builds, "block_builds_block_id_fkey")
    alter table(:block_builds) do
      modify :block_id, references(:block_requests, type: :uuid, on_delete: :delete_all), null: false
    end
    
    # BlockSubppls
    drop constraint(:block_subppls, "block_subppls_block_id_fkey")
    alter table(:block_subppls) do
      modify :block_id, references(:block_requests, type: :uuid, on_delete: :delete_all), null: false
    end
  end
  
  def down do
    # Blocks
    drop constraint(:blocks, "blocks_block_id_fkey")
    alter table(:blocks) do
      modify :block_id, references(:block_requests, type: :uuid, on_delete: :nothing), null: false
    end
    
    # BlockBuilds
    drop constraint(:block_builds, "block_builds_block_id_fkey")
    alter table(:block_builds) do
      modify :block_id, references(:block_requests, type: :uuid, on_delete: :nothing), null: false
    end
    
    # BlockSubppls
    drop constraint(:block_subppls, "block_subppls_block_id_fkey")
    alter table(:block_subppls) do
      modify :block_id, references(:block_requests, type: :uuid, on_delete: :nothing), null: false
    end
  end
end
