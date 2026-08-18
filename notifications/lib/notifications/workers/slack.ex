defmodule Notifications.Workers.Slack do
  require Logger

  def publish(request_id, nil, _, _) do
    Watchman.increment("notification.slack.skipped")

    Logger.info("#{request_id} Slack target has empty endpoint - skipping")

    :skipped
  end

  def publish(request_id, "", _, _) do
    Watchman.increment("notification.slack.skipped")

    Logger.info("#{request_id} Slack target has empty endpoint - skipping")

    :skipped
  end

  def publish(request_id, url, [], data), do: publish(request_id, url, nil, data)

  def publish(request_id, url, channels, data) when is_list(channels) do
    Enum.each(channels, fn channel -> publish(request_id, url, channel, data) end)
  end

  def publish(request_id, url, channel, data) do
    case Notifications.Egress.UrlGuard.verify(url) do
      :ok ->
        do_publish(request_id, url, channel, data)

      {:error, reason} ->
        Watchman.increment("notification.slack.blocked")

        Logger.info(fn ->
          "#{request_id} Slack endpoint blocked by egress guard (#{inspect(reason)}) host=#{safe_host(url)}"
        end)

        {:error, :ssrf_blocked}
    end
  end

  defp do_publish(request_id, url, channel, data) do
    body = Notifications.Workers.Slack.Message.construct(channel, data) |> Poison.encode!()
    headers = [{"Content-type", "application/json"}]
    options = [follow_redirect: false]

    Watchman.benchmark("notification.slack.duration", fn ->
      case HTTPoison.request(:post, url, body, headers, options) do
        {:ok, response} ->
          Logger.info(fn ->
            "#{request_id} Success with #{url} #{body}"
          end)

          Watchman.increment("notification.slack.success")

          {:ok, response}

        {:error, error} ->
          Logger.info(fn ->
            "#{request_id} Failure with #{url} #{body}"
          end)

          Watchman.increment("notification.slack.failure")

          {:error, error}
      end
    end)
  end

  defp safe_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> "invalid"
    end
  end

  defp safe_host(_), do: "invalid"
end
