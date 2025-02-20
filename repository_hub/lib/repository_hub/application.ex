defmodule RepositoryHub.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    env = Application.fetch_env!(:repository_hub, :environment)

    grpc_port = Application.fetch_env!(:repository_hub, :grpc_listen_port)

    Logger.info("Running application in #{env} environment")

    children =
      filter_enabled([
        {{Task.Supervisor, name: RepositoryHub.SentryEventSupervisor}, true},
        {{RepositoryHub.Repo, []}, true},
        {{GRPC.Server.Supervisor, endpoint: RepositoryHub.Server.Endpoint, port: grpc_port, start_server: true}, true},
        {{RepositoryHub.RemoteRepositoryChangedConsumer, []}, true},
        # Used by feature provider to cache results
        {{Cachex, name: :feature_provider_cache}, true},
        webhook_encryptor_worker_spec(),
        feature_provider()
      ])

    opts = [strategy: :one_for_one, name: RepositoryHub.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def webhook_encryptor_worker_spec do
    config = Application.get_env(:repository_hub, RepositoryHub.WebhookEncryptor)
    {{RepositoryHub.WebhookEncryptor, []}, config[:start] == true}
  end

  def filter_enabled(list) do
    list
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
  end

  defp feature_provider do
    provider = Application.get_env(FeatureProvider, :provider)

    {provider, System.get_env("FEATURE_YAML_PATH") != nil}
  end
end
