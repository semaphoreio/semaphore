defmodule Gofer.DeploymentTrigger.Engine.Supervisor do
  @moduledoc """
  Dynamic supervisor delegating synchronization of secrets
  with Secrethub to separate processes.
  """

  use DynamicSupervisor

  alias Gofer.DeploymentTrigger.Model
  alias Model.DeploymentTriggerQueries, as: Queries
  alias Model.DeploymentTrigger, as: Trigger
  alias Gofer.DeploymentTrigger.Engine.Worker

  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch

  def start_link(args),
    do: DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)

  def init(_args), do: DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 1_000)

  # starting workers

  def start_worker(switch = %Switch{}, deployment = %Deployment{}, params),
    do: DynamicSupervisor.start_child(__MODULE__, {Worker, {switch, deployment, params}})

  def start_worker(trigger = %Trigger{}),
    do: DynamicSupervisor.start_child(__MODULE__, {Worker, trigger})

  def start_worker(trigger_id) when is_binary(trigger_id) do
    case Queries.find_by_id(trigger_id) do
      {:ok, trigger = %Trigger{}} -> start_worker(trigger)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def start_worker(switch_trigger_id, target_name) do
    case Queries.find_by_switch_trigger_and_target(switch_trigger_id, target_name) do
      {:ok, trigger = %Trigger{}} -> start_worker(trigger)
      {:error, :not_found} -> {:error, :not_found}
    end
  end
end
