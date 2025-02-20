defmodule Ppl.EctoRepo.Migrations.AddRepositoryIdToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add(:repository_id, :string)
    end
  end
end
