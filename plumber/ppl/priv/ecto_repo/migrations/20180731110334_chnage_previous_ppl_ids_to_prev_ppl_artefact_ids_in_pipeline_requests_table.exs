defmodule Ppl.EctoRepo.Migrations.ChnagePreviousPplIdsToPrevPplArtefactIdsInPipelineRequestsTable do
  use Ecto.Migration
  import Ecto.Query
  alias Ppl.EctoRepo, as: Repo

  def up do
    alter table(:pipeline_requests) do
      add :prev_ppl_artefact_ids, {:array, :string}
    end

    flush()

    from(p in "pipeline_requests",
      update: [set: [prev_ppl_artefact_ids: p.previous_ppl_ids]],
      where: is_nil(p.prev_ppl_artefact_ids))
    |> Repo.update_all([])

    alter table(:pipeline_requests) do
      remove :previous_ppl_ids
    end
  end

  def down do
    alter table(:pipeline_requests) do
      add :previous_ppl_ids,   {:array, :string}
    end

    flush()

    from(p in "pipeline_requests",
      update: [set: [previous_ppl_ids: p.prev_ppl_artefact_ids]],
      where: is_nil(p.previous_ppl_ids))
    |> Repo.update_all([])

    alter table(:pipeline_requests) do
      remove :prev_ppl_artefact_ids
    end
  end

end
