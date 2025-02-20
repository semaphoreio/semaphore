defmodule Ppl.EctoRepo.Migrations.AddFastFailingToPipelinesTable do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :fast_failing, :string
    end
  end
end
