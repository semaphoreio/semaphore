defmodule BranchHub.Application do
  require Logger

  use Application

  @impl true
  @grpc_port 50_051
  def start(_type, _args) do
    children = [
      {BranchHub.Repo, []},
      {GRPC.Server.Supervisor, {[BranchHub.Server, GrpcHealthCheck.Server], @grpc_port}}
    ]

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    opts = [strategy: :one_for_one, name: BranchHub.Supervisor, max_restarts: 1000]
    Supervisor.start_link(children, opts)
  end
end
