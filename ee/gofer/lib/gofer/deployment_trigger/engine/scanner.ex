defmodule Gofer.DeploymentTrigger.Engine.Scanner do
  @moduledoc """
  Restarts deployment trigger workers on startup
  """

  use Gofer.GenericScanner
  alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries, as: TriggerQueries
  alias Gofer.DeploymentTrigger.Engine.Supervisor

  def start_link(args) do
    default_args = [
      start_worker_fun: &Supervisor.start_worker/1,
      scanner_fun: &TriggerQueries.scan_runnable/3
    ]

    args = Keyword.merge(default_args, args)
    Gofer.GenericScanner.start_link(__MODULE__, args)
  end
end
