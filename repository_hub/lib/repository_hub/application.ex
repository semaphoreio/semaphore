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

    guard_cleanup_worker = Application.get_env(:repository_hub, RepositoryHub.BuildStatusGuardCleanupWorker, [])
    guard_cleanup_worker_enabled = Keyword.get(guard_cleanup_worker, :enabled, false)

    {feature_provider_module, feature_provider_opts} = Application.get_env(FeatureProvider, :provider)

    children =
      filter_enabled([
        {{Task.Supervisor, name: RepositoryHub.SentryEventSupervisor}, true},
        {{RepositoryHub.Repo, []}, true},
        {{RepositoryHub.MaxStatusesCache, []}, true},
        {%{id: FeatureProvider.Cachex, start: {Cachex, :start_link, [:feature_provider_cache, []]}}, true},
        {{FeatureProvider.CircuitBreaker, name: :feature_provider_breaker}, true},
        {{feature_provider_module, feature_provider_opts}, feature_provider_module == FeatureProvider.YamlProvider},
        {{RepositoryHub.GithubAppId, []}, true},
        {{RepositoryHub.CheckRunCache, []}, true},
        {{GRPC.Server.Supervisor, endpoint: RepositoryHub.Server.Endpoint, port: grpc_port, start_server: true}, true},
        {{RepositoryHub.RemoteRepositoryChangedConsumer, []}, true},
        {{RepositoryHub.FeatureProviderInvalidatorWorker, []}, true},
        {{RepositoryHub.RemoteIdSyncWorker, remote_id_sync_worker_opts}, remote_id_sync_worker_enabled},
        {{RepositoryHub.BuildStatusGuardCleanupWorker, []}, guard_cleanup_worker_enabled}
      ])

    opts = [strategy: :one_for_one, name: RepositoryHub.Supervisor, max_restarts: 1000]

    Supervisor.start_link(children, opts)
  end

  def filter_enabled(list) do
    list
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
  end
end
