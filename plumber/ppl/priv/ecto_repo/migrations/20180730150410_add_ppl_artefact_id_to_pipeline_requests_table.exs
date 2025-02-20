defmodule Ppl.EctoRepo.Migrations.AddPplArtefactIdToPipelineRequestsTable do
  use Ecto.Migration
  import Ecto.Query
  alias Ppl.EctoRepo, as: Repo

  def up do
    alter table(:pipeline_requests) do
      add :ppl_artefact_id, :string
    end

    flush()

    from(p in "pipeline_requests",
      update: [set: [ppl_artefact_id: p.id]],
      where: is_nil(p.ppl_artefact_id))
    |> Repo.update_all([])
  end

  def down do
    alter table(:pipeline_requests) do
      remove :ppl_artefact_id
    end
  end
end
