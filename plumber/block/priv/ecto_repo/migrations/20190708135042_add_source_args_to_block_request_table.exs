defmodule Block.EctoRepo.Migrations.AddSourceArgsToBlockRequestTable do
  use Ecto.Migration

  def change do
    alter table(:block_requests) do
      add :source_args, :map
    end
  end
end
