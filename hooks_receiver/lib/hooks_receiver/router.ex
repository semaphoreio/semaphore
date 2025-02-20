defmodule HooksReceiver.Router do
  use Plug.Router

  require Logger

  alias InternalApi.Hooks.ReceivedWebhook

  plug(Plug.Logger)

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    body_reader: {HooksReceiver.Plugs.CacheBodyReader, :read_body, []},
    json_decoder: JSON
  )

  plug(:dispatch)

  post "/bitbucket" do
    conn |> handle_payload(:bitbucket)
  end

  post "/gitlab" do
    conn |> handle_payload(:gitlab)
  end

  post "/git" do
    conn |> handle_payload(:git)
  end

  get "/health_check/ping" do
    send_resp(conn, 200, "pong")
  end

  # Root path has to return 200 OK in order to pass health checks made by Kubernetes
  get "/" do
    send_resp(conn, 200, "pong")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp handle_payload(conn, provider) do
    [raw_body | _] = conn.assigns[:raw_body]
    Logger.info("Webhook content: #{inspect(conn.params)}")

    case HooksReceiver.Hook.Validator.run(provider, conn.req_headers, conn.params) do
      {true, hook_data} ->
        if System.get_env("PUBLISH_TO_RABBIT") == "true" do
          publish_webhook(provider, hook_data, raw_body)
        end

        send_resp(conn, 200, "Webhook received.")

      _ ->
        send_resp(conn, 404, "oops")
    end
  end

  defp publish_webhook(provider, hook_data, raw_body) do
    options = %{
      exchange: "received_webhooks_exchange",
      routing_key: provider |> Atom.to_string(),
      url: System.get_env("RABBITMQ_URL")
    }

    now = DateTime.utc_now()

    %ReceivedWebhook{
      received_at: %{
        seconds: DateTime.to_unix(now, :second),
        nanos: elem(now.microsecond, 0) * 1_000
      },
      webhook: JSON.encode!(hook_data.webhook),
      repository_id: hook_data.repository_id,
      project_id: hook_data.project_id,
      organization_id: hook_data.org_id,
      webhook_signature: hook_data.signature,
      webhook_raw_payload: raw_body
    }
    |> ReceivedWebhook.encode()
    |> Tackle.publish(options)
  end
end
