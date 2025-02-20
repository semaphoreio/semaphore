defmodule Badges.Application do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec

    http_port = Application.get_env(:badges, :http_port)

    children =
      filter_enabled([
        {{Plug.Cowboy, scheme: :http, plug: Badges.Api, options: [port: http_port]},
         enabled?("START_WEB_SERVICE")}
      ])

    children =
      children ++
        [
          worker(Cachex, [:badges_cache, []])
        ]

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    Logger.configure_backend(Sentry.LoggerBackend, include_logger_metadata: true)

    opts = [strategy: :one_for_one, name: Badges.Supervisor, max_restarts: 1000]
    Supervisor.start_link(children, opts)
  end

  def enabled?(env_var) do
    System.get_env(env_var) == "true" && !IEx.started?()
  end

  def filter_enabled(list) do
    list
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
  end
end
