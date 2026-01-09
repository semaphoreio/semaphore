defmodule RepositoryHub.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    env = Application.fetch_env!(:repository_hub, :environment)

    grpc_port = Application.fetch_env!(:repository_hub, :grpc_listen_port)

    Logger.info("Running application in #{env} environment")

    remote_id_sync_worker = Application.get_env(:repository_hub, RepositoryHub.RemoteIdSyncWorker, [])
    remote_id_sync_worker_enabled = Keyword.get(remote_id_sync_worker, :enabled, false)
    remote_id_sync_worker_opts = Keyword.delete(remote_id_sync_worker, :enabled)

    children =
      filter_enabled([
        {{Task.Supervisor, name: RepositoryHub.SentryEventSupervisor}, true},
        {{RepositoryHub.Repo, []}, true},
        {{GRPC.Server.Supervisor, endpoint: RepositoryHub.Server.Endpoint, port: grpc_port, start_server: true}, true},
        {{RepositoryHub.RemoteRepositoryChangedConsumer, []}, true},
        {{RepositoryHub.RemoteIdSyncWorker, remote_id_sync_worker_opts}, remote_id_sync_worker_enabled}
      ])

    opts = [strategy: :one_for_one, name: RepositoryHub.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def filter_enabled(list) do
    list
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
  end
end
