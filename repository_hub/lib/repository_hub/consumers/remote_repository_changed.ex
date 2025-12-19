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

      log(event, "Start")

      RepositoryHub.Adapters.from_repository_id(event)
      |> RepositoryHub.Toolkit.unwrap(fn adapter ->
        RepositoryHub.SyncRepositoryAction.execute(adapter, event.repository_id)
        |> RepositoryHub.Toolkit.unwrap_error(fn e ->
          log(event, "Error during Repository Sync: #{e.inspect}")
        end)
      end)
      |> RepositoryHub.Toolkit.unwrap_error(fn e ->
        log(event, "Error during Repository lookup: #{e.inspect}")
      end)

      log(event, "Finish")
    end)
  end

  defp log(%{repository_id: repository_id}, message) when is_binary(repository_id) and repository_id != "" do
    log_msg("repository_id: #{repository_id}", message)
  end

  defp log(%{remote_id: remote_id}, message) when is_binary(remote_id) and remote_id != "" do
    log_msg("repository_id: #{repository_id}", message)
  end

  defp log(_, message), do: :noop

  defp log_msg(sufix, message) do
    Logger.info("[RemoteRepositoryChanged] #{sufix}: #{message}")
  end
end
