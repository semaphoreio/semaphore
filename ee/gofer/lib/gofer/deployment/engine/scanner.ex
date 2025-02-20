defmodule Gofer.Deployment.Engine.Scanner do
  @moduledoc """
  Restarts deployment secret sychronization workers on startup
  """

  use Gofer.GenericScanner
  alias Gofer.Deployment.Engine.Supervisor
  alias Gofer.Deployment.Model.DeploymentQueries

  def start_link(args) do
    default_args = [
      start_worker_fun: &Supervisor.start_worker/1,
      scanner_fun: &DeploymentQueries.scan_syncing/3
    ]

    args = Keyword.merge(default_args, args)
    Gofer.GenericScanner.start_link(__MODULE__, args)
  end
end
