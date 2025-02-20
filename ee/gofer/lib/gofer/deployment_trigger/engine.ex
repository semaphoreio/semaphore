defmodule Gofer.DeploymentTrigger.Engine do
  @moduledoc false
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      Gofer.DeploymentTrigger.Engine.Supervisor,
      Gofer.DeploymentTrigger.Engine.Scanner
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
