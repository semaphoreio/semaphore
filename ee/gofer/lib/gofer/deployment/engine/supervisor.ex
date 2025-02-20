defmodule Gofer.Deployment.Engine.Supervisor do
  @moduledoc """
  Dynamic supervisor delegating synchronization of secrets
  with Secrethub to separate processes.
  """

  use DynamicSupervisor

  alias Gofer.Deployment.Engine.Worker

  def start_link(args),
    do: DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)

  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 1_000)
  end

  # starting workers

  def start_worker(dpl_id),
    do: DynamicSupervisor.start_child(__MODULE__, {Worker, dpl_id})
end
