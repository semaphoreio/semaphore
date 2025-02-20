defmodule Secrethub.Application do
  @moduledoc false

  use Application
  require Logger
  import Cachex.Spec

  def start_internal_grpc?, do: (System.get_env("START_INTERNAL_GRPC_API") || "true") == "true"
  def start_public_grpc?, do: (System.get_env("START_PUBLIC_GRPC_API") || "true") == "true"

  def start_deletion_consumer?,
    do: (System.get_env("START_DELETION_CONSUMER") || "true") == "true"

  def start_openid_connect_services?,
    do: (System.get_env("START_OPENID_CONNECT_HTTP_API") || "true") == "true"

  def start_openid_key_manager?,
    do: (System.get_env("START_OPENID_KEY_MANAGER") || "true") == "true"

  def start_stub_grpc_services?,
    do:
      Application.get_env(:secrethub, :environment) == :test ||
        Application.get_env(:secrethub, :environment) == :dev

  def start(_type, _args) do
    stub_external_grpc_apis()

    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    FeatureProvider.init()

    children = [
      {Secrethub.Repo, []},
      %{id: :auth_cache, start: {Cachex, :start_link, [:auth_cache, []]}},
      %{id: :feature_cache, start: {Cachex, :start_link, [:feature_cache, []]}},
      %{
        id: :oidc_usage,
        start:
          {Cachex, :start_link,
           [:oidc_usage, [expiration: Cachex.Spec.expiration(default: :timer.hours(24))]]}
      }
    ]

    children =
      children ++
        grpc_services() ++ openid_connect_services() ++ openid_key_manager() ++ workers()

    opts = [strategy: :one_for_one, name: Secrets.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def stub_external_grpc_apis do
    if start_stub_grpc_services?() do
      {:ok, _} = FunRegistry.start()

      if Application.get_env(:secrethub, :environment) == :dev do
        Support.FakeServices.stub_responses()
      end
    end
  end

  defp workers do
    if start_deletion_consumer?() do
      [Secrethub.Workers.OwnerDeletedConsumer]
    else
      []
    end
  end

  defp openid_key_manager do
    if start_openid_key_manager?() do
      keys_path = Application.fetch_env!(:secrethub, :openid_keys_path)

      [
        {Secrethub.OpenIDConnect.KeyManager,
         [
           name: :openid_keys,
           keys_path: keys_path
         ]}
      ]
    else
      []
    end
  end

  defp openid_connect_services do
    if start_openid_connect_services?() do
      port = Application.get_env(:secrethub, :openid_connect_http_port)

      Logger.info("Starting Open ID Connect HTTP server on port #{port}")

      [
        Plug.Cowboy.child_spec(
          scheme: :http,
          plug: Secrethub.OpenIDConnect.HTTPServer,
          options: [port: port]
        )
      ]
    else
      []
    end
  end

  defp grpc_services do
    services = [GrpcHealthCheck.Server]

    services =
      services ++
        if start_internal_grpc?() do
          [Secrethub.InternalGrpcApi]
        else
          []
        end

    services =
      services ++
        if start_public_grpc?() do
          [Secrethub.PublicGrpcApi, Secrethub.ProjectSecretsPublicApi]
        else
          []
        end

    services =
      services ++
        if start_stub_grpc_services?() do
          [
            Support.FakeServices.FeatureService,
            Support.FakeServices.ProjecthubService,
            Support.FakeServices.RbacService
          ]
        else
          []
        end

    if length(services) > 0 do
      grpc_port = Application.get_env(:secrethub, :grpc_port)

      Logger.info("Starting GRPC APIs (#{inspect(services)}) on port #{grpc_port}")

      [{GRPC.Server.Supervisor, {services, grpc_port}}]
    else
      []
    end
  end
end
