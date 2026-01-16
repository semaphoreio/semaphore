defmodule Ppl.Retention.Events do
  @moduledoc """
  Publishes pipeline and workflow deletion events to RabbitMQ.
  """

  alias Google.Protobuf.Timestamp
  alias InternalApi.Plumber.PipelineDeleted
  alias InternalApi.PlumberWF.WorkflowDeleted
  alias Looper.Publisher.AMQP, as: AmqpPublisher

  @pipeline_exchange "plumber.pipeline_deletion_exchange"
  @workflow_exchange "plumber.workflow_deletion_exchange"
  @routing_key "deleted"

  @spec publish_pipeline_deleted(String.t(), String.t(), String.t() | nil, String.t() | nil, String.t() | nil) ::
          :ok | {:error, term()}
  def publish_pipeline_deleted(pipeline_id, workflow_id, org_id, project_id, artifact_store_id) do
    PipelineDeleted.new(
      pipeline_id: pipeline_id || "",
      workflow_id: workflow_id || "",
      organization_id: org_id || "",
      project_id: project_id || "",
      artifact_store_id: artifact_store_id || "",
      deleted_at: now_timestamp()
    )
    |> PipelineDeleted.encode()
    |> publish(@pipeline_exchange)
  end

  @spec publish_workflow_deleted(String.t(), String.t() | nil, String.t() | nil, String.t() | nil) ::
          :ok | {:error, term()}
  def publish_workflow_deleted(workflow_id, org_id, project_id, artifact_store_id) do
    WorkflowDeleted.new(
      workflow_id: workflow_id || "",
      organization_id: org_id || "",
      project_id: project_id || "",
      artifact_store_id: artifact_store_id || "",
      deleted_at: now_timestamp()
    )
    |> WorkflowDeleted.encode()
    |> publish(@workflow_exchange)
  end

  defp publish(message, exchange) do
    AmqpPublisher.publish(%{
      exchange: exchange,
      routing_key: @routing_key,
      message: message
    })
  rescue
    e -> {:error, e}
  end

  defp now_timestamp do
    Timestamp.new(seconds: DateTime.to_unix(DateTime.utc_now()), nanos: 0)
  end
end
