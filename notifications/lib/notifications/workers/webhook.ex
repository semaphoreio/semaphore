defmodule Notifications.Workers.Webhook do
  require Logger

  alias Notifications.Workers.Webhook

  def publish(_request_id, %{endpoint: endpoint}, _) when is_nil(endpoint) or endpoint == "" do
    Watchman.increment("notification.webhook.skipped")

    :skipped
  end

  def publish(request_id, settings, data) do
    endpoint = settings.endpoint
    method = if(settings.action == "", do: "post", else: settings.action)
    timeout = if(settings.timeout == 0, do: 500, else: settings.timeout)

    body = Webhook.Message.construct(data) |> Poison.encode!()
    signature = get_signature(body, data.organization.org_id, settings.secret)
    headers = get_headers(signature)
    options = [timeout: 1000, recv_timeout: timeout, follow_redirect: false]

    Watchman.benchmark("notification.webhook.duration", fn ->
      case HTTPoison.request(method, endpoint, body, headers, options) do
        {:ok, response} ->
          Logger.debug(fn ->
            "#{request_id} Success with #{endpoint} #{body} and signature '#{signature}'"
          end)

          Watchman.increment("notification.webhook.success")

          {:ok, response}

        {:error, error} ->
          Logger.error(fn ->
            "#{request_id} Failure with #{endpoint} error: #{inspect(error)}"
          end)
          Watchman.increment("notification.webhook.failure")

          {:error, error}
      end
    end)
  end

  defp get_headers(signature \\ nil)

  defp get_headers(signature) when is_binary(signature) and signature != "",
    do: get_headers() ++ [{"X-Semaphore-Signature-256", signature}]

  defp get_headers(_),
    do: [{"Content-type", "application/json"}, {"User-Agent", "Semaphore-Webhook"}]

  defp get_signature(body, org_id, secret_name) do
    case Webhook.Secret.get(org_id, secret_name) do
      {:ok, secret} ->
        Webhook.Signature.sign(body, secret)

      _ ->
        nil
    end
  end
end
