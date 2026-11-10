defmodule Notifications.Workers.SlackTest do
  use Notifications.DataCase
  import Mock

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

    test "does not send to an internal address or a URL with control characters" do
      with_mock HTTPoison, request: fn _, _, _, _, _ -> {:ok, %HTTPoison.Response{}} end do
        for url <- [
              "http://169.254.0.1/",
              "http://[::1]:4000/",
              "https://hooks.slack.com/services/A?b=1\r\nX-Header: value"
            ] do
          assert {:error, _} = Slack.publish("1", url, "#dev-null", %{})
        end

        assert_not_called(HTTPoison.request(:_, :_, :_, :_, :_))
      end
    end
  end
end
