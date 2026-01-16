defmodule Notifications.Workers.WebhookTest do
  use Notifications.DataCase
  import Mock

  alias Notifications.Workers.Webhook

  @endpoint "https://hooks.slack.com/services/ABCDEF01234/9876FEDCBA/abcdef0123456789"

  describe ".publish" do
    test "sends message to webhook" do
      settings = %{
        endpoint: @endpoint,
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

    test "skips when endpoint is nil" do
      settings = %{endpoint: nil, action: "post", timeout: 0}
      s = Notifications.Models.Rule.decode_webhook(settings)

      assert Webhook.publish("1", s, %{}) == :skipped
    end

    test "skips when endpoint is empty string" do
      settings = %{endpoint: "", action: "post", timeout: 0}
      s = Notifications.Models.Rule.decode_webhook(settings)

      assert Webhook.publish("1", s, %{}) == :skipped
    end
  end

  describe "retry behavior on timeout errors" do
    setup do
      {:ok, data: build_test_data(), settings: build_test_settings()}
    end

    test "retries on :timeout error and succeeds on retry", %{data: data, settings: settings} do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _headers, _opts ->
          attempt = Agent.get_and_update(agent, fn count -> {count, count + 1} end)

          if attempt < 2 do
            {:error, %HTTPoison.Error{id: nil, reason: :timeout}}
          else
            {:ok, %HTTPoison.Response{status_code: 200, body: "ok"}}
          end
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        assert {:ok, %HTTPoison.Response{status_code: 200}} = Webhook.publish("test-1", s, data)

        call_count = Agent.get(agent, & &1)
        assert call_count == 3
      end

      Agent.stop(agent)
    end

    test "retries on :connect_timeout error and succeeds on retry", %{
      data: data,
      settings: settings
    } do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _headers, _opts ->
          attempt = Agent.get_and_update(agent, fn count -> {count, count + 1} end)

          if attempt < 1 do
            {:error, %HTTPoison.Error{id: nil, reason: :connect_timeout}}
          else
            {:ok, %HTTPoison.Response{status_code: 200, body: "ok"}}
          end
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        assert {:ok, %HTTPoison.Response{status_code: 200}} = Webhook.publish("test-2", s, data)

        call_count = Agent.get(agent, & &1)
        assert call_count == 2
      end

      Agent.stop(agent)
    end

    test "fails after max retries exceeded", %{data: data, settings: settings} do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _headers, _opts ->
          Agent.update(agent, fn count -> count + 1 end)
          {:error, %HTTPoison.Error{id: nil, reason: :timeout}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        assert {:error, %HTTPoison.Error{reason: :timeout}} = Webhook.publish("test-3", s, data)

        call_count = Agent.get(agent, & &1)
        assert call_count == 4
      end

      Agent.stop(agent)
    end

    test "does not retry on non-timeout errors", %{data: data, settings: settings} do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _headers, _opts ->
          Agent.update(agent, fn count -> count + 1 end)
          {:error, %HTTPoison.Error{id: nil, reason: :econnrefused}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        assert {:error, %HTTPoison.Error{reason: :econnrefused}} =
                 Webhook.publish("test-4", s, data)

        call_count = Agent.get(agent, & &1)
        assert call_count == 1
      end

      Agent.stop(agent)
    end

    test "does not retry on HTTP error responses", %{data: data, settings: settings} do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _headers, _opts ->
          Agent.update(agent, fn count -> count + 1 end)
          {:ok, %HTTPoison.Response{status_code: 500, body: "Internal Server Error"}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        assert {:ok, %HTTPoison.Response{status_code: 500}} = Webhook.publish("test-5", s, data)

        call_count = Agent.get(agent, & &1)
        assert call_count == 1
      end

      Agent.stop(agent)
    end

    test "succeeds on first attempt without retry", %{data: data, settings: settings} do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _headers, _opts ->
          Agent.update(agent, fn count -> count + 1 end)
          {:ok, %HTTPoison.Response{status_code: 200, body: "ok"}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        assert {:ok, %HTTPoison.Response{status_code: 200}} = Webhook.publish("test-6", s, data)

        call_count = Agent.get(agent, & &1)
        assert call_count == 1
      end

      Agent.stop(agent)
    end

    test "increases timeouts on each retry", %{data: data} do
      settings_default_timeout = %{
        endpoint: @endpoint,
        action: "post",
        timeout: 0,
        secret: ""
      }

      {:ok, agent} = Agent.start_link(fn -> [] end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _headers, opts ->
          Agent.update(agent, fn calls -> calls ++ [opts] end)
          {:error, %HTTPoison.Error{id: nil, reason: :timeout}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings_default_timeout)

        Webhook.publish("test-7", s, data)

        calls = Agent.get(agent, & &1)

        assert length(calls) == 4

        [first, second, third, fourth] = calls

        assert first[:timeout] == 1000
        assert first[:recv_timeout] == 500

        assert second[:timeout] == 2000
        assert second[:recv_timeout] == 1000

        assert third[:timeout] == 4000
        assert third[:recv_timeout] == 2000

        assert fourth[:timeout] == 5000
        assert fourth[:recv_timeout] == 4000
      end

      Agent.stop(agent)
    end

    test "caps timeouts at max value of 5000ms", %{data: data} do
      settings_high_timeout = %{
        endpoint: @endpoint,
        action: "post",
        timeout: 2000,
        secret: ""
      }

      {:ok, agent} = Agent.start_link(fn -> [] end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, _headers, opts ->
          Agent.update(agent, fn calls -> calls ++ [opts] end)
          {:error, %HTTPoison.Error{id: nil, reason: :timeout}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings_high_timeout)

        Webhook.publish("test-8", s, data)

        calls = Agent.get(agent, & &1)

        [_first, _second, third, fourth] = calls

        assert third[:recv_timeout] == 5000
        assert fourth[:recv_timeout] == 5000
      end

      Agent.stop(agent)
    end

    test "includes X-Semaphore-Webhook-Id header with unique UUID", %{
      data: data,
      settings: settings
    } do
      {:ok, agent} = Agent.start_link(fn -> [] end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, headers, _opts ->
          Agent.update(agent, fn calls -> calls ++ [headers] end)
          {:ok, %HTTPoison.Response{status_code: 200, body: "ok"}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        Webhook.publish("test-9", s, data)

        [headers] = Agent.get(agent, & &1)

        webhook_id_header =
          Enum.find(headers, fn {name, _} -> name == "X-Semaphore-Webhook-Id" end)

        assert webhook_id_header != nil
        {_, webhook_id} = webhook_id_header
        assert {:ok, _} = Ecto.UUID.cast(webhook_id)
      end

      Agent.stop(agent)
    end

    test "uses same webhook ID across retries", %{data: data, settings: settings} do
      {:ok, agent} = Agent.start_link(fn -> [] end)

      with_mock HTTPoison,
        request: fn _method, _url, _body, headers, _opts ->
          Agent.update(agent, fn calls -> calls ++ [headers] end)
          {:error, %HTTPoison.Error{id: nil, reason: :timeout}}
        end do
        s = Notifications.Models.Rule.decode_webhook(settings)

        Webhook.publish("test-10", s, data)

        calls = Agent.get(agent, & &1)

        webhook_ids =
          Enum.map(calls, fn headers ->
            {_, id} = Enum.find(headers, fn {name, _} -> name == "X-Semaphore-Webhook-Id" end)
            id
          end)

        assert length(Enum.uniq(webhook_ids)) == 1
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

  defp build_test_settings do
    %{
      endpoint: @endpoint,
      action: "post",
      timeout: 100,
      secret: ""
    }
  end
end
