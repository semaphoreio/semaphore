defmodule Ppl.Retention.EventsTest do
  use Ppl.IntegrationCase, async: false

  import Mock

  alias InternalApi.Plumber.PipelineDeleted
  alias InternalApi.PlumberWF.WorkflowDeleted
  alias Ppl.Retention.Events

  describe "publish_pipeline_deleted/5" do
    test "publishes pipeline deletion event" do
      test_pid = self()

      with_mock Looper.Publisher.AMQP,
        publish: fn payload ->
          send(test_pid, {:published, payload})
          :ok
        end do
        :ok = Events.publish_pipeline_deleted("ppl-1", "wf-1", "org-1", "proj-1", "art-1")

        assert_receive {:published, %{exchange: "plumber.pipeline_deletion_exchange", routing_key: "deleted", message: message}}

        event = PipelineDeleted.decode(message)
        assert event.pipeline_id == "ppl-1"
        assert event.workflow_id == "wf-1"
        assert event.organization_id == "org-1"
        assert event.project_id == "proj-1"
        assert event.artifact_store_id == "art-1"
        assert event.deleted_at.seconds > 0
      end
    end

    test "handles nil values by converting to empty strings" do
      test_pid = self()

      with_mock Looper.Publisher.AMQP,
        publish: fn payload ->
          send(test_pid, {:published, payload})
          :ok
        end do
        :ok = Events.publish_pipeline_deleted("ppl-1", "wf-1", nil, nil, nil)

        assert_receive {:published, %{message: message}}

        event = PipelineDeleted.decode(message)
        assert event.organization_id == ""
        assert event.project_id == ""
        assert event.artifact_store_id == ""
      end
    end

    test "returns error when publishing fails" do
      with_mock Looper.Publisher.AMQP, publish: fn _payload -> {:error, :failed} end do
        assert {:error, :failed} = Events.publish_pipeline_deleted("ppl-1", "wf-1", "org-1", "proj-1", "art-1")
      end
    end
  end

  describe "publish_workflow_deleted/4" do
    test "publishes workflow deletion event" do
      test_pid = self()

      with_mock Looper.Publisher.AMQP,
        publish: fn payload ->
          send(test_pid, {:published, payload})
          :ok
        end do
        :ok = Events.publish_workflow_deleted("wf-1", "org-1", "proj-1", "art-1")

        assert_receive {:published, %{exchange: "plumber.workflow_deletion_exchange", routing_key: "deleted", message: message}}

        event = WorkflowDeleted.decode(message)
        assert event.workflow_id == "wf-1"
        assert event.organization_id == "org-1"
        assert event.project_id == "proj-1"
        assert event.artifact_store_id == "art-1"
        assert event.deleted_at.seconds > 0
      end
    end

    test "returns error when publishing fails" do
      with_mock Looper.Publisher.AMQP, publish: fn _payload -> {:error, :failed} end do
        assert {:error, :failed} = Events.publish_workflow_deleted("wf-1", "org-1", "proj-1", "art-1")
      end
    end
  end
end
