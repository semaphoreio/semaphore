defmodule Notifications.Workers.SlackTest do
  use Notifications.DataCase

  alias Notifications.Workers.Slack

  describe ".publish" do
    test "sends message to slack" do
      url = "https://hooks.slack.com/services/ABCDEF01234/9876FEDCBA/abcdef0123456789"
      channel = "#dev-null"

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

      assert Slack.publish(request_id, url, channel, data)
    end
  end
end
