defmodule Ppl.EctoRepo.Migrations.AddPreviousPplIdsToPipelineRequestsTable do
  use Ecto.Migration

  def change do
    alter table(:pipeline_requests) do
      add :previous_ppl_ids,   {:array, :string}
    end
  end
end
