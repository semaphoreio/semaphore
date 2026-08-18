defmodule Notifications.Workers.SlackTest do
  use Notifications.DataCase
  import Mock

  alias Notifications.Workers.Slack

  describe ".publish" do
    test "sends message to slack" do
      url = "https://hooks.slack.com/services/ABCDEF01234/9876FEDCBA/abcdef0123456789"
      channel = "#dev-null"

      request_id = "1"

      assert Slack.publish(request_id, url, channel, build_data())
    end

    test "blocks a private-resolving url without issuing the request" do
      url = "https://private.internal.test/services/x"

      with_mock HTTPoison,
        request: fn _m, _u, _b, _h, _o ->
          flunk("HTTPoison must not be called for a blocked host")
        end do
        assert Slack.publish("blk-1", url, "#dev-null", build_data()) == {:error, :ssrf_blocked}
        assert_not_called(HTTPoison.request(:_, :_, :_, :_, :_))
      end
    end

    test "blocks a cloud-metadata url" do
      url = "http://169.254.169.254/latest/meta-data/"

      assert Slack.publish("blk-2", url, "#dev-null", build_data()) == {:error, :ssrf_blocked}
    end

    test "allows a public url through to the request with follow_redirect disabled" do
      url = "https://hooks.slack.com/services/T00/B00/xxxx"

      with_mock HTTPoison,
        request: fn _m, _u, _b, _h, opts ->
          assert opts[:follow_redirect] == false
          {:ok, %HTTPoison.Response{status_code: 200, body: "ok"}}
        end do
        assert {:ok, %HTTPoison.Response{status_code: 200}} =
                 Slack.publish("ok-1", url, "#dev-null", build_data())

        assert_called(HTTPoison.request(:_, :_, :_, :_, :_))
      end
    end

    test "channel list fans out and blocks each private url" do
      url = "https://private.internal.test/services/x"

      with_mock HTTPoison,
        request: fn _m, _u, _b, _h, _o ->
          flunk("HTTPoison must not be called for a blocked host")
        end do
        assert Slack.publish("blk-3", url, ["#a", "#b"], build_data()) == :ok
        assert_not_called(HTTPoison.request(:_, :_, :_, :_, :_))
      end
    end
  end

  defp build_data do
    project = Support.Factories.Project.build()
    workflow = Support.Factories.Workflow.build(project)

    %{
      project: project,
      pipeline: Support.Factories.Pipeline.build(project, workflow),
      blocks: [Support.Factories.Block.build()],
      hook: Support.Factories.Hook.build(),
      organization: Support.Factories.Organization.build(),
      workflow: workflow
    }
  end
end
