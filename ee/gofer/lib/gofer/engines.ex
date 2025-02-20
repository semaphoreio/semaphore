defmodule Gofer.Engines do
  @moduledoc """
  Supervises Gofer's engine processes
  """
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      Gofer.Switch.Engine.SwitchSupervisor,
      Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor,
      Gofer.TargetTrigger.Engine.TargetTriggerSupervisor,
      Gofer.TargetTrigger.Engine.DbScanner,
      Gofer.SwitchTrigger.Engine.DbScanner,
      Gofer.Switch.Engine.DbScanner,
      Gofer.Deployment.Engine,
      Gofer.DeploymentTrigger.Engine
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
