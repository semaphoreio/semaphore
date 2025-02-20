defmodule Gofer.TargetTrigger.Engine.TargetTriggerSupervisor do
  @moduledoc """
  Supervisor for Target_trigger processes.
  """

  use DynamicSupervisor

  alias Gofer.TargetTrigger.Engine.TargetTriggerProcess

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 1000,
      extra_arguments: []
    )
  end

  def start_target_trigger_process(switch_trigger_id, target_name) do
    spec = {TargetTriggerProcess, {switch_trigger_id, target_name}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def finish_target_trigger_process(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def children() do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def count_children() do
    DynamicSupervisor.count_children(__MODULE__)
  end
end
