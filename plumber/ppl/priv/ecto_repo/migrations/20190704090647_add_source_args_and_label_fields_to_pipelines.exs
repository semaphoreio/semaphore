defmodule Ppl.EctoRepo.Migrations.AddSourceArgsAndLabelFieldsToPipelines do
  use Ecto.Migration

  def change do
    alter table(:pipeline_requests) do
      add :source_args, :map
    end

    alter table(:pipelines) do
      add :label, :string
    end
  end
end
