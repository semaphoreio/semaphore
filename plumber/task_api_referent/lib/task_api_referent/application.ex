defmodule TaskApiReferent.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # FIXME
    Application.stop(:watchman)
    Application.ensure_all_started(:watchman)

    services = [
      TaskApiReferent.Grpc.Server,
      TaskApiReferent.Grpc.HealthCheck,
    ]

    children = [
      supervisor(GRPC.Server.Supervisor, [{services, 50_051}]),
      worker(TaskApiReferent.Agent.Task, []),
      worker(TaskApiReferent.Agent.Job, []),
      worker(TaskApiReferent.Agent.Command, []),
    ]

    opts = [strategy: :one_for_one, name: TaskApiReferent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
