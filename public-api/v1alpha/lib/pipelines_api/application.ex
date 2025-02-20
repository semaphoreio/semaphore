defmodule PipelinesAPI.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  import Supervisor.Spec, warn: false

  alias PipelinesAPI.Util.Config
  alias Support

  def start(_type, _args) do
    "K8S_NAMESPACE" |> Config.set_watchman_prefix("ppl-api") |> Config.restart_app()

    provider = Application.fetch_env!(:pipelines_api, :feature_provider)
    FeatureProvider.init(provider)

    children =
      [
        {Plug.Cowboy, scheme: :http, plug: PipelinesAPI.Router, options: [port: 4004]},
        worker(Cachex, [:feature_provider_cache, []], id: :feature_provider_cache),
        worker(Cachex, [:project_api_cache, []], id: :project_api_cache)
      ] ++ if Application.fetch_env!(:pipelines_api, :on_prem?), do: [provider], else: []

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PipelinesAPI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
