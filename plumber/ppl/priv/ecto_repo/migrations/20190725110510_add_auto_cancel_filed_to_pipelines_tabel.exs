defmodule Ppl.EctoRepo.Migrations.AddAutoCancelFiledToPipelinesTabel do
  use Ecto.Migration

  def change do
    alter table(:pipelines) do
      add :auto_cancel, :string
    end
  end
end
