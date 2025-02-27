defmodule Guard.Services.InstanceConfigInvalidatorWorker do
  require Logger

  @doc """
  This module consumes RabbitMQ instance config change events
  and invalidates instance config caches.
  """

  use Tackle.Consumer,
    url: Application.get_env(:guard, :amqp_url),
    exchange: "instance_config_exchange",
    routing_key: "modified",
    service: "guard",
    queue: :dynamic,
    queue_opts: [
      durable: false,
      auto_delete: true,
      exclusive: true
    ]

  def handle_message(message) do
    event = InternalApi.InstanceConfig.ConfigModified.decode(message)

    cache_key =
      InternalApi.InstanceConfig.ConfigType.key(event.type)
      |> cache_key()

    if cache_key, do: Cachex.del(:config_cache, cache_key)
    Logger.info("Invalidated Instance Config Cache with key: #{inspect(cache_key)}")

    :ok
  end

  defp cache_key(:CONFIG_TYPE_GITHUB_APP), do: "github_credentials"
  defp cache_key(:CONFIG_TYPE_BITBUCKET_APP), do: "bitbucket_credentials"
  defp cache_key(:CONFIG_TYPE_GITLAB_APP), do: "gitlab_credentials"
  defp cache_key(_), do: nil
end
