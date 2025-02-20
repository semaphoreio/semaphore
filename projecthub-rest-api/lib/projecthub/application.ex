defmodule Projecthub.Application do
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    http_port = Application.get_env(:projecthub, :http_port)

    Logger.info("Starting HTTP server on port #{http_port}")

    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Projecthub.HttpApi,
        options: [port: http_port]
      ),
      %{id: Cachex, start: {Cachex, :start_link, [:auth_cache, []]}}
    ]

    opts = [strategy: :one_for_one, name: Projecthub.Supervisor]

    unless Application.get_env(:projecthub, :enviroment) == :dev ||
             Application.get_env(:projecthub, :enviroment) == :test do
      {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    end

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    Supervisor.start_link(children, opts)
  end
end
