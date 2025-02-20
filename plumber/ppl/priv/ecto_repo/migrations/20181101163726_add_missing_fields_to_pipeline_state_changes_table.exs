defmodule Ppl.EctoRepo.Migrations.AddMissingFieldsToPipelineStateChangesTable do
  use Ecto.Migration

  def change do
    alter table(:pipeline_state_changes) do
      add :terminate_request, :string
      add :terminate_request_desc, :string
      add :to_do,  {:array, :string}, default: []
    end
  end
end
