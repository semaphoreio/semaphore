defmodule HooksReceiver.Router.Test do
  use ExUnit.Case

  alias InternalApi.Hooks.ReceivedWebhook

  import Mock

  test "POST /bitbucket responds with 200" do
    hook_data = %{
      project_id: "some-project-id",
      org_id: "some-org-id",
      repository_id: "some-repo-id",
      webhook: %{test_param: "value"},
      signature: ""
    }

    with_mock HooksReceiver.Hook.Validator,
      run: fn _, _req_headers, _params -> {true, hook_data} end do
      {:ok, response} = hook_data |> JSON.encode!() |> bitbucket_post_hook()
      %{:body => body, :status_code => 200} = response
      assert body == "Webhook received."
    end
  end

  test "POST /gitlab responds with 200" do
    hook_data = %{
      project_id: "some-project-id",
      org_id: "some-org-id",
      repository_id: "some-repo-id",
      webhook: %{test_param: "value"},
      signature: ""
    }

    with_mock HooksReceiver.Hook.Validator,
      run: fn _, _req_headers, _params -> {true, hook_data} end do
      {:ok, response} = hook_data |> JSON.encode!() |> gitlab_post_hook()
      %{:body => body, :status_code => 200} = response
      assert body == "Webhook received."
    end
  end

  test "POST /bitbucket puts webhook on RabbitMQ" do
    hook_data = %{
      project_id: "some-project-id",
      org_id: "some-org-id",
      repository_id: "some-repo-id",
      webhook: %{test_param: "value"},
      signature: ""
    }

    with_mock HooksReceiver.Hook.Validator,
      run: fn _, _req_headers, _params -> {true, hook_data} end do
      start_supervised!(HooksReceiver.Router.Test.TestConsumer.Bitbucket)

      ts_beore = DateTime.utc_now()
      {:ok, response} = hook_data |> JSON.encode!() |> bitbucket_post_hook()
      %{:body => body, :status_code => 200} = response
      assert body == "Webhook received."

      :timer.sleep(1_000)

      timestamp = Application.get_env(:hooks_receiver, :bitbucket_test_timestamp)

      assert DateTime.compare(timestamp, ts_beore) == :gt

      webhook = :hooks_receiver |> Application.get_env(:test_webhook) |> JSON.decode!()

      assert webhook == %{"test_param" => "value"}
    end
  end

  test "POST /gitlab puts webhook on RabbitMQ" do
    hook_data = %{
      project_id: "some-project-id",
      org_id: "some-org-id",
      repository_id: "some-repo-id",
      webhook: %{test_param: "value"},
      signature: ""
    }

    with_mock HooksReceiver.Hook.Validator,
      run: fn _, _req_headers, _params -> {true, hook_data} end do
      start_supervised!(HooksReceiver.Router.Test.TestConsumer.Gitlab)

      ts_beore = DateTime.utc_now()
      {:ok, response} = hook_data |> JSON.encode!() |> gitlab_post_hook()
      %{:body => body, :status_code => 200} = response
      assert body == "Webhook received."

      :timer.sleep(1_000)

      timestamp = Application.get_env(:hooks_receiver, :gitlab_test_timestamp)

      assert DateTime.compare(timestamp, ts_beore) == :gt

      webhook = :hooks_receiver |> Application.get_env(:test_webhook) |> JSON.decode!()

      assert webhook == %{"test_param" => "value"}
    end
  end

  test "router healt_check responds" do
    assert {:ok, response} = get_health_check()
    assert %{:body => "pong", :status_code => 200} = response
  end

  test "router base route returns 200" do
    assert {:ok, response} = get_base_route()
    assert %{:body => "pong", :status_code => 200} = response
  end

  test "invalid url returns 404" do
    assert {:ok, response} = HTTPoison.get(url() <> "/invalid_path", headers())
    assert %{:body => "oops", :status_code => 404} = response
  end

  def url, do: "localhost:4000"

  def headers, do: [{"Content-type", "application/json"}]

  defp bitbucket_post_hook(body) do
    HTTPoison.post(url() <> "/bitbucket", body, headers(), timeout: 50_000, recv_timeout: 50_000)
  end

  defp gitlab_post_hook(body) do
    HTTPoison.post(url() <> "/gitlab", body, headers(), timeout: 50_000, recv_timeout: 50_000)
  end

  defp get_health_check, do: HTTPoison.get(url() <> "/health_check/ping", headers())

  defp get_base_route, do: HTTPoison.get(url(), headers())

  defmodule TestConsumer.Bitbucket do
    use Tackle.Consumer,
      url: System.get_env("RABBITMQ_URL"),
      exchange: "received_webhooks_exchange",
      routing_key: "bitbucket",
      service: "test-service"

    def handle_message(message) do
      struct = message |> ReceivedWebhook.decode()

      Application.put_env(
        :hooks_receiver,
        :bitbucket_test_timestamp,
        timestamp_to_datetime(struct.received_at)
      )

      Application.put_env(:hooks_receiver, :test_webhook, struct.webhook)
    end

    defp timestamp_to_datetime(%{nanos: nanos, seconds: seconds}) do
      ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
      {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
      ts_date_time
    end
  end

  defmodule TestConsumer.Gitlab do
    use Tackle.Consumer,
      url: System.get_env("RABBITMQ_URL"),
      exchange: "received_webhooks_exchange",
      routing_key: "gitlab",
      service: "test-service"

    def handle_message(message) do
      struct = message |> ReceivedWebhook.decode()

      Application.put_env(
        :hooks_receiver,
        :gitlab_test_timestamp,
        timestamp_to_datetime(struct.received_at)
      )

      Application.put_env(:hooks_receiver, :test_webhook, struct.webhook)
    end

    defp timestamp_to_datetime(%{nanos: nanos, seconds: seconds}) do
      ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
      {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
      ts_date_time
    end
  end
end
