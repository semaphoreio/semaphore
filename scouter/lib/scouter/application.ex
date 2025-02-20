defmodule Scouter.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    Logger.info(
      "Starting Scouter application in '#{Application.get_env(:scouter, :env)}' environment"
    )

    children = [
      Scouter.Repo,
      grpc_server()
    ]

    opts = [strategy: :one_for_one, name: Scouter.Supervisor]

    Enum.each(children, fn child ->
      Logger.info("Starting #{inspect(child)}")
    end)

    Supervisor.start_link(children, opts)
  end

  defp grpc_server do
    {GRPC.Server.Supervisor,
     [
       endpoint: Scouter.GRPC.Endpoint,
       port: Application.fetch_env!(:scouter, :grpc_listen_port),
       start_server: true
     ]}
  end
end
