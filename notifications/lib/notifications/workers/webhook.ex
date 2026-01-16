defmodule Notifications.Workers.Webhook do
  require Logger

  alias Notifications.Workers.Webhook

  @default_connect_timeout 5_000
  @default_recv_timeout 5_000

  def publish(_request_id, %{endpoint: endpoint}, _) when is_nil(endpoint) or endpoint == "" do
    Watchman.increment("notification.webhook.skipped")

    :skipped
  end

  def publish(request_id, settings, data) do
    endpoint = settings.endpoint
    method = if(settings.action == "", do: "post", else: settings.action)
    recv_timeout = if(settings.timeout == 0, do: @default_recv_timeout, else: settings.timeout)

    webhook_id = Ecto.UUID.generate()

    body = Webhook.Message.construct(data) |> Poison.encode!()
    signature = get_signature(body, data.organization.org_id, settings.secret)
    headers = get_headers(webhook_id, signature)

    options = [
      timeout: @default_connect_timeout,
      recv_timeout: recv_timeout,
      follow_redirect: false
    ]

    Watchman.benchmark("notification.webhook.duration", fn ->
      case HTTPoison.request(method, endpoint, body, headers, options) do
        {:ok, response} ->
          Logger.debug(fn ->
            "#{request_id} #{webhook_id} Success with #{endpoint} #{body} and signature '#{signature}'"
          end)

          Watchman.increment("notification.webhook.success")

          {:ok, response}

        {:error, error} ->
          Logger.error(fn ->
            "#{request_id} #{webhook_id} Failure with #{endpoint} error: #{inspect(error)}"
          end)

          Watchman.increment("notification.webhook.failure")

          {:error, error}
      end
    end)
  end

  defp get_headers(webhook_id, signature) when is_binary(signature) and signature != "",
    do: base_headers(webhook_id) ++ [{"X-Semaphore-Signature-256", signature}]

  defp get_headers(webhook_id, _), do: base_headers(webhook_id)

  defp base_headers(webhook_id) do
    [
      {"Content-type", "application/json"},
      {"User-Agent", "Semaphore-Webhook"},
      {"X-Semaphore-Webhook-Id", webhook_id}
    ]
  end

  defp get_signature(body, org_id, secret_name) do
    case Webhook.Secret.get(org_id, secret_name) do
      {:ok, secret} ->
        Webhook.Signature.sign(body, secret)

      _ ->
        nil
    end
  end
end
