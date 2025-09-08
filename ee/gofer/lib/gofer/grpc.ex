defmodule Gofer.Grpc do
  @moduledoc """
  gRPC server supervisor definition
  """

  use GRPC.Endpoint

  run Gofer.Grpc.HealthCheck

  run Gofer.Grpc.Server

  run Gofer.Grpc.DeploymentTargets.Server,
    interceptors: [
      {Gofer.Grpc.Watchman, prefix: "Gofer.grpc.deployment-targets"}
    ]

  @port 50_055
  def child_spec([]) do
    start_args = {GRPC.Server.Supervisor, :start_link, [{__MODULE__, @port}]}
    %{id: Gofer.Grpc, start: start_args, type: :supervisor, shutdown: :infinity}
  end
end
