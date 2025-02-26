defmodule Audit.Application do
  @moduledoc false

  use Application

  @grpc_port 50_051

  def start(_type, _args) do
    provider = Application.fetch_env!(:audit, :feature_provider)
    FeatureProvider.init(provider)

    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    env = Application.get_env(:audit, :environment)

    grpc_options = {grpc_services(env), @grpc_port}

    children = [
      {{Audit.Repo, []}, true},
      {{Audit.Consumer, []}, enabled?("START_CONSUMER")},
      {{GRPC.Server.Supervisor, grpc_options}, enabled?("START_GRPC_API")},
      {{Audit.Streamer.Scheduler, []}, enabled?("START_STREAMER")},
      {{Cachex, [name: Audit.Cache]}, true},
      {provider, System.get_env("FEATURE_YAML_PATH") != nil},
      {Supervisor.child_spec({Cachex, :feature_provider_cache}, id: :feature_provider_cache),
       true}
    ]

    children = filter_enabled_children(children)

    opts = [strategy: :one_for_one, name: Audit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp grpc_services(:test),
    do: [
      Audit.Api
    ]

  defp grpc_services(:dev), do: grpc_services(:test)
  defp grpc_services(:prod), do: [GrpcHealthCheck.Server, Audit.Api]

  defp filter_enabled_children(children) do
    children
    |> Enum.filter(fn {_child, enabled} -> enabled end)
    |> Enum.map(fn {child, _} -> child end)
  end

  defp enabled?(env_var), do: System.get_env(env_var) == "true" && !IEx.started?()
end
