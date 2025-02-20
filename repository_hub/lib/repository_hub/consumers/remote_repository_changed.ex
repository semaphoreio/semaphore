defmodule RepositoryHub.RemoteRepositoryChangedConsumer do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:repository_hub, :amqp_url),
    exchange: "repository_exchange",
    routing_key: "remote_repository_changed",
    service: "repository.remote_repository_changed"

  def handle_message(message) do
    Watchman.benchmark("remote_repository_changed.duration", fn ->
      event = InternalApi.Repository.RemoteRepositoryChanged.decode(message)

      log(event.remote_id, "Start")

      # mark repositories as watiging for sync

      log(event.remote_id, "Finish")
    end)
  end

  defp log(remote_id, message) do
    Logger.info("[RemoteRepositoryChanged] #{remote_id}: #{message}")
  end
end
