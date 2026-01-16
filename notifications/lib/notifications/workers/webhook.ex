defmodule Notifications.Workers.Webhook do
  require Logger

  alias Notifications.Workers.Webhook

  @default_connect_timeout 1_000
  @default_recv_timeout 500
  @max_timeout 5_000
  @max_retries 3
  @initial_retry_delay_ms 500

  def publish(_request_id, %{endpoint: endpoint}, _) when is_nil(endpoint) or endpoint == "" do
    Watchman.increment("notification.webhook.skipped")

    :skipped
  end

  def publish(request_id, settings, data) do
    endpoint = settings.endpoint
    method = if(settings.action == "", do: "post", else: settings.action)
    recv_timeout = if(settings.timeout == 0, do: @default_recv_timeout, else: settings.timeout)

    body = Webhook.Message.construct(data) |> Poison.encode!()
    signature = get_signature(body, data.organization.org_id, settings.secret)
    headers = get_headers(signature)

    options = [
      timeout: @default_connect_timeout,
      recv_timeout: recv_timeout,
      follow_redirect: false
    ]

    req = %{
      method: method,
      endpoint: endpoint,
      body: body,
      headers: headers,
      options: options,
      signature: signature
    }

    Watchman.benchmark("notification.webhook.duration", fn ->
      do_request_with_retry(request_id, req, 0)
    end)
  end

  defp do_request_with_retry(request_id, req, attempt) do
    case HTTPoison.request(req.method, req.endpoint, req.body, req.headers, req.options) do
      {:ok, response} ->
        Logger.debug(fn ->
          "#{request_id} Success with #{req.endpoint} #{req.body} and signature '#{req.signature}'"
        end)

        Watchman.increment("notification.webhook.success")

        {:ok, response}

      {:error, %HTTPoison.Error{reason: :timeout} = error} ->
        handle_timeout_error(request_id, req, attempt, error)

      {:error, %HTTPoison.Error{reason: :connect_timeout} = error} ->
        handle_timeout_error(request_id, req, attempt, error)

      {:error, error} ->
        Logger.error(fn ->
          "#{request_id} Failure with #{req.endpoint} error: #{inspect(error)}"
        end)

        Watchman.increment("notification.webhook.failure")

        {:error, error}
    end
  end

  defp handle_timeout_error(request_id, req, attempt, error) do
    if attempt < @max_retries do
      delay = retry_delay(attempt)
      new_req = increase_timeouts(req, attempt + 1)

      Logger.warning(fn ->
        "#{request_id} Timeout on attempt #{attempt + 1}/#{@max_retries + 1} with #{req.endpoint}, " <>
          "retrying in #{delay}ms with increased timeouts. Error: #{inspect(error)}"
      end)

      Watchman.increment("notification.webhook.retry")

      Process.sleep(delay)

      do_request_with_retry(request_id, new_req, attempt + 1)
    else
      Logger.error(fn ->
        "#{request_id} Failure with #{req.endpoint} after #{@max_retries + 1} attempts, error: #{inspect(error)}"
      end)

      Watchman.increment("notification.webhook.failure")

      {:error, error}
    end
  end

  defp retry_delay(attempt) do
    (@initial_retry_delay_ms * :math.pow(2, attempt)) |> round()
  end

  defp increase_timeouts(req, _attempt) do
    current_opts = req.options

    new_timeout = min(current_opts[:timeout] * 2, @max_timeout)
    new_recv_timeout = min(current_opts[:recv_timeout] * 2, @max_timeout)

    new_opts =
      current_opts
      |> Keyword.put(:timeout, new_timeout)
      |> Keyword.put(:recv_timeout, new_recv_timeout)

    %{req | options: new_opts}
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
