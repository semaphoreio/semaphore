defmodule Notifications.Workers.WebhookTest do
  use Notifications.DataCase

  alias Notifications.Workers.Webhook

  describe ".publish" do
    test "sends message to webhook" do
      settings = %{
        endpoint: "https://hooks.slack.com/services/ABCDEF01234/9876FEDCBA/abcdef0123456789",
        action: "post",
        timeout: 200,
        retries: 1
      }

      project = Support.Factories.Project.build()
      workflow = Support.Factories.Workflow.build(project)

      data = %{
        project: project,
        pipeline: Support.Factories.Pipeline.build(project, workflow),
        blocks: [Support.Factories.Block.build()],
        hook: Support.Factories.Hook.build(),
        organization: Support.Factories.Organization.build(),
        workflow: workflow
      }

      request_id = "1"
      s = Notifications.Models.Rule.decode_webhook(settings)

      assert Webhook.publish(request_id, s, data)
    end
  end
end
