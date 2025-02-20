defmodule Ppl.EctoRepo.Migrations.AddWorkflowIdToPipelineRequestsTable do
  use Ecto.Migration

  def up do
    execute """
      UPDATE pipeline_requests AS p1
      SET request_args = p1.request_args ||
        (SELECT row_to_json(t)
         FROM
          (SELECT request_args ->>'hook_id' as workflow_id
           FROM pipeline_requests AS p2
           WHERE p1.id = p2.id )
          as t)::jsonb
      WHERE p1.request_args->>'workflow_id' IS NULL;
    """
  end

  def down do
    execute """
      UPDATE pipeline_requests
      SET request_args = request_args - 'workflow_id'
      WHERE request_args->>'workflow_id' = request_args ->>'hook_id';
    """
  end
end
