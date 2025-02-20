defmodule Gofer.Deployment.Engine do
  @moduledoc false
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      Gofer.Deployment.Engine.Supervisor,
      Gofer.Deployment.Engine.Scanner,
      Gofer.Deployment.Engine.Destroyer
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
