defmodule PipelinesAPI.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    provider = Application.fetch_env!(:pipelines_api, :feature_provider)
    FeatureProvider.init(provider)
    on_prem? = Application.fetch_env!(:pipelines_api, :on_prem?)

    children =
      [
        {Plug.Cowboy, scheme: :http, plug: PipelinesAPI.Router, options: [port: 4004]},
        %{
          id: :feature_provider_cache,
          start: {Cachex, :start_link, [:feature_provider_cache, []]}
        },
        %{
          id: :project_api_cache,
          start: {Cachex, :start_link, [:project_api_cache, []]}
        }
      ] ++ maybe_feature_provider_invalidator() ++ if on_prem?, do: [provider], else: []

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PipelinesAPI.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_feature_provider_invalidator do
    case Application.get_env(:pipelines_api, :amqp_url) do
      nil -> []
      "" -> []
      _ -> [PipelinesAPI.FeatureProviderInvalidatorWorker]
    end
  end
end
