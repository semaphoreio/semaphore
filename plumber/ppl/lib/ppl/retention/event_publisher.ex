defmodule Ppl.Retention.EventPublisher do
  alias Google.Protobuf.Timestamp
  alias InternalApi.Plumber.PipelineDeleted
  alias InternalApi.PlumberWF.WorkflowDeleted
  alias Looper.Publisher.AMQP, as: AmqpPublisher

  @pipeline_deletion_exchange "plumber.pipeline_deletion_exchange"
  @workflow_deletion_exchange "plumber.workflow_deletion_exchange"
  @routing_key "deleted"

  def publish_pipeline_deleted(pipeline_id, workflow_id, org_id, project_id, artifact_store_id) do
    event =
      PipelineDeleted.new(
        pipeline_id: pipeline_id,
        workflow_id: workflow_id,
        organization_id: org_id,
        project_id: project_id,
        artifact_store_id: artifact_store_id,
        deleted_at: current_timestamp()
      )

    publish(PipelineDeleted.encode(event), @pipeline_deletion_exchange)
  end

  def publish_workflow_deleted(workflow_id, org_id, project_id, artifact_store_id) do
    event =
      WorkflowDeleted.new(
        workflow_id: workflow_id,
        organization_id: org_id,
        project_id: project_id,
        artifact_store_id: artifact_store_id,
        deleted_at: current_timestamp()
      )

    publish(WorkflowDeleted.encode(event), @workflow_deletion_exchange)
  end

  defp publish(message, exchange) do
    payload = %{exchange: exchange, routing_key: @routing_key, message: message}

    case AmqpPublisher.publish(payload) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  rescue
    error -> {:error, error}
  end

  defp current_timestamp do
    now = DateTime.utc_now()
    Timestamp.new(seconds: DateTime.to_unix(now), nanos: 0)
  end
end
