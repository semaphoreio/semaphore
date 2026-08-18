defmodule Notifications.Workers.Slack do
  require Logger

  alias Notifications.Egress.UrlGuard

  def publish(request_id, nil, _, _), do: skip(request_id)
  def publish(request_id, "", _, _), do: skip(request_id)

  def publish(request_id, url, channels, data) do
    # Verify (resolve + classify + pin) exactly once per URL, before any
    # channel fan-out, so the guard runs a single DNS resolution and every
    # channel dials the same vetted IP.
    case UrlGuard.verify(url) do
      {:ok, target} ->
        dispatch(request_id, url, target, channels, data)

      {:error, reason} ->
        Watchman.increment("notification.slack.blocked")

        Logger.info(fn ->
          "#{request_id} Slack endpoint blocked by egress guard (#{inspect(reason)}) host=#{safe_host(url)}"
        end)

        {:error, :ssrf_blocked}
    end
  end

  defp skip(request_id) do
    Watchman.increment("notification.slack.skipped")

    Logger.info("#{request_id} Slack target has empty endpoint - skipping")

    :skipped
  end

  defp dispatch(request_id, url, target, channels, data) when is_list(channels) do
    channels
    |> case do
      [] -> [nil]
      list -> list
    end
    |> Enum.each(fn channel -> do_publish(request_id, url, target, channel, data) end)
  end

  defp dispatch(request_id, url, target, channel, data) do
    do_publish(request_id, url, target, channel, data)
  end

  defp do_publish(request_id, url, target, channel, data) do
    body = Notifications.Workers.Slack.Message.construct(channel, data) |> Poison.encode!()
    headers = [{"Content-type", "application/json"}, {"Host", target.host_header}]
    options = [follow_redirect: false] ++ ssl_option(target)

    Watchman.benchmark("notification.slack.duration", fn ->
      case HTTPoison.request(:post, target.url, body, headers, options) do
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

  defp ssl_option(%{ssl_options: []}), do: []
  defp ssl_option(%{ssl_options: opts}), do: [ssl: opts]

  defp safe_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> "invalid"
    end
  end

  defp safe_host(_), do: "invalid"
end
