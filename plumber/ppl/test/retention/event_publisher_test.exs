defmodule Ppl.Retention.EventPublisherTest do
  use ExUnit.Case, async: false

  import Mock

  alias InternalApi.Plumber.PipelineDeleted
  alias InternalApi.PlumberWF.WorkflowDeleted
  alias Ppl.Retention.EventPublisher

  test "publish_pipeline_deleted publishes pipeline deletion event" do
    with_mock Looper.Publisher.AMQP, publish: fn payload ->
      send(self(), {:published, payload})
      :ok
    end do
      :ok = EventPublisher.publish_pipeline_deleted("ppl-1", "wf-1", "org-1", "proj-1", "art-1")

      assert_receive {:published,
                      %{exchange: "plumber.pipeline_deletion_exchange", routing_key: "deleted", message: message}}

      event = PipelineDeleted.decode(message)
      assert event.pipeline_id == "ppl-1"
      assert event.workflow_id == "wf-1"
      assert event.organization_id == "org-1"
      assert event.project_id == "proj-1"
      assert event.artifact_store_id == "art-1"
      assert event.deleted_at.seconds > 0
    end
  end

  test "publish_workflow_deleted publishes workflow deletion event" do
    with_mock Looper.Publisher.AMQP, publish: fn payload ->
      send(self(), {:published, payload})
      :ok
    end do
      :ok = EventPublisher.publish_workflow_deleted("wf-1", "org-1", "proj-1", "art-1")

      assert_receive {:published,
                      %{exchange: "plumber.workflow_deletion_exchange", routing_key: "deleted", message: message}}

      event = WorkflowDeleted.decode(message)
      assert event.workflow_id == "wf-1"
      assert event.organization_id == "org-1"
      assert event.project_id == "proj-1"
      assert event.artifact_store_id == "art-1"
      assert event.deleted_at.seconds > 0
    end
  end

  test "publish_pipeline_deleted returns error when publishing fails" do
    with_mock Looper.Publisher.AMQP, publish: fn _payload -> {:error, :failed} end do
      assert {:error, :failed} ==
               EventPublisher.publish_pipeline_deleted("ppl-1", "wf-1", "org-1", "proj-1", "art-1")
    end
  end
end
