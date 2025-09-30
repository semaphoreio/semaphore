defmodule EphemeralEnvironments.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    Logger.info(
      "Starting EphemeralEnvironments in '#{Application.get_env(:ephemeral_environments, :env)}' environment"
    )

    grpc_port = Application.get_env(:ephemeral_environments, :grpc_listen_port)

    children = [
      EphemeralEnvironments.Repo,
      {GRPC.Server.Supervisor,
        servers: [EphemeralEnvironments.Grpc.EphemeralEnvironmentsServer],
        port: Application.get_env(:ephemeral_environments, :grpc_listen_port),
        start_server: true,
        adapter_opts: [ip: {0, 0, 0, 0}]}
    ]

    opts = [strategy: :one_for_one, name: EphemeralEnvironments.Supervisor]
    Enum.each(children, fn child -> Logger.info("Starting #{inspect(child)}") end)
    Supervisor.start_link(children, opts)
  end
end
