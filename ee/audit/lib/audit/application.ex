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
      {{Cachex, [name: Audit.Cache]}, true},
      {Supervisor.child_spec({Cachex, :feature_provider_cache}, id: :feature_provider_cache),
       true},
      {provider, System.get_env("FEATURE_YAML_PATH") != nil},
      {{Audit.Consumer, []}, enabled?("START_CONSUMER")},
      {{GRPC.Server.Supervisor, grpc_options}, enabled?("START_GRPC_API")},
      {{Audit.Streamer.Scheduler, []}, enabled?("START_STREAMER")},
      {{Audit.FeatureProviderInvalidatorWorker, []}, true}
    ]

    children =
      children
      |> filter_enabled_children()
      |> Kernel.++(retention_worker_children())

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

  @doc false
  def retention_worker_children do
    policy_enabled = retention_policy_enabled?()
    deleter_enabled = retention_deleter_enabled?()

    children = []

    children =
      if policy_enabled do
        children ++ [Audit.Retention.PolicyMarker]
      else
        children
      end

    if deleter_enabled do
      children ++ [Audit.Retention.Deleter]
    else
      children
    end
  end

  defp retention_policy_enabled? do
    config = Application.get_env(:audit, Audit.Retention.PolicyMarker, [])
    Keyword.get(config, :enabled, false)
  end

  defp retention_deleter_enabled? do
    config = Application.get_env(:audit, Audit.Retention.Deleter, [])
    Keyword.get(config, :enabled, false)
  end

  defp enabled?(env_var), do: System.get_env(env_var) == "true" && !IEx.started?()
end
