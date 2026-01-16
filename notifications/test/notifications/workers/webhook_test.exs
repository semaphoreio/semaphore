defmodule Notifications.Workers.WebhookTest do
  use Notifications.DataCase

  import Mock

  alias Notifications.Workers.Webhook

  @endpoint "https://hooks.slack.com/services/ABCDEF01234/9876FEDCBA/abcdef0123456789"

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

    test "includes X-Semaphore-Webhook-Id header with unique UUID" do
      settings = %{
        endpoint: @endpoint,
        action: "post",
        timeout: 100,
        secret: ""
      }

      data = build_test_data()

      {:ok, agent} = Agent.start_link(fn -> [] end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, headers, _opts ->
          Agent.update(agent, fn calls -> calls ++ [headers] end)
          {:ok, %HTTPoison.Response{status_code: 200, body: "ok"}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        Webhook.publish("test-header", s, data)

        [headers] = Agent.get(agent, & &1)

        webhook_id_header =
          Enum.find(headers, fn {name, _} -> name == "X-Semaphore-Webhook-Id" end)

        assert webhook_id_header != nil
        {_, webhook_id} = webhook_id_header
        assert {:ok, _} = Ecto.UUID.cast(webhook_id)
      end

      Agent.stop(agent)
    end
  end

  defp build_test_data do
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
