defmodule Ppl.EctoRepo.Migrations.ExtractWorkflowIdFromRequestArgsInPipelineRequestsTable do
  use Ecto.Migration
  import Ecto.Query
  alias Ppl.EctoRepo, as: Repo

  def up do
    alter table(:pipeline_requests) do
      add :wf_id, :string
    end

    flush()

    from(p in "pipeline_requests",
      update: [set: [wf_id: fragment("?->>?", p.request_args, "workflow_id")]],
      where: is_nil(p.wf_id))
    |> Repo.update_all([])


    execute """
      UPDATE pipeline_requests
      SET request_args = request_args - 'workflow_id';
    """
  end

  def down do
    execute """
      UPDATE pipeline_requests AS p1
      SET request_args = p1.request_args ||
        (SELECT row_to_json(t)
         FROM
          (SELECT p2.wf_id as workflow_id
           FROM pipeline_requests AS p2
           WHERE p1.id = p2.id )
          as t)::jsonb
      WHERE p1.request_args->>'workflow_id' IS NULL;
    """

    alter table(:pipeline_requests) do
      remove :wf_id
    end
  end
end
