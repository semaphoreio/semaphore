defmodule PublicAPI.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  import Supervisor.Spec, warn: false

  alias Support

  def start(_type, _args) do
    provider = Application.fetch_env!(:public_api, :feature_provider)
    FeatureProvider.init(provider)

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PublicAPI.Supervisor]
    Supervisor.start_link(children(Application.get_env(:public_api, :environment)), opts)
  end

  def children(:test) do
    [
      {Plug.Cowboy, scheme: :http, plug: PublicAPI.Router, options: [port: 4004]}
    ] ++
      cache() ++ async_tasks()
  end

  def children(:dev) do
    Support.Stubs.init()
    Support.MockData.mock()

    Enum.concat(children(:test), children_())
  end

  def children(_), do: Enum.concat(children(:test), children_())

  def children_ do
    []
  end

  def cache() do
    opts = %{
      prefix: Application.get_env(:public_api, :cache_prefix),
      backend: %{
        type: :redis,
        host: Application.get_env(:public_api, :cache_host),
        port: Application.get_env(:public_api, :cache_port),
        pool_size: Application.get_env(:public_api, :cache_pool_size)
      }
    }

    [
      {Cacheman, [:public_api, opts]},
      {Cachex, name: :feature_provider_cache}
    ]
  end

  @doc "Used by PublicAPI.Async to supervise async tasks"
  def async_tasks() do
    [
      {Task.Supervisor, name: PublicAPI.TaskSupervisor}
    ]
  end
end
