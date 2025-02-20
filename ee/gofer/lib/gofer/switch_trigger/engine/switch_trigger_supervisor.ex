defmodule Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor do
  @moduledoc """
  Supervisor for switch_trigger processes.
  """

  use DynamicSupervisor

  alias Gofer.SwitchTrigger.Engine.SwitchTriggerProcess
  alias LogTee, as: LT

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

  def start_switch_trigger_process(id, params) do
    spec = {SwitchTriggerProcess, {id, params}}

    DynamicSupervisor.start_child(__MODULE__, spec)
    |> log(id, params)
  end

  def finish_switch_trigger_process(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def children() do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def count_children() do
    DynamicSupervisor.count_children(__MODULE__)
  end

  defp log(resp = {:ok, _pid}, id, params) do
    LT.info(params["switch_id"], "SwitchTrigger process with id #{id} started for switch")
    resp
  end

  defp log({:error, error}, _id, params) do
    LT.warn(
      error,
      "SwitchTrigger process for switch with id #{params["switch_id"]} - error while starting"
    )

    {:error, error}
  end

  defp log(error, _id, params) do
    LT.warn(
      error,
      "SwitchTrigger process for switch with id #{params["switch_id"]} - error while starting"
    )
  end
end
