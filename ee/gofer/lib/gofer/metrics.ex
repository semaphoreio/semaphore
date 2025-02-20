defmodule Gofer.Metrics do
  @moduledoc """
  Supervises metrics sent to Grafana
  """
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    children = Keyword.get(args, :children, default_children())
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp default_children do
    [
      Gofer.EngineMetrics,
      Gofer.DeploymentMetrics,
      Gofer.CacheMetrics
    ]
  end
end
