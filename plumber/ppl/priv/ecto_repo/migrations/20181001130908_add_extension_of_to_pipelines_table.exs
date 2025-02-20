defmodule Ppl.EctoRepo.Migrations.AddExtensionOfToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :extension_of, :string
    end
  end
end
