defmodule Gofer.Switch.Engine.SwitchSupervisor do
  @moduledoc """
  Supervisor for switch processes.
  """

  use DynamicSupervisor

  alias Gofer.Switch.Engine.SwitchProcess
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

  def start_switch_process(id, params) do
    spec = {SwitchProcess, {id, params}}

    DynamicSupervisor.start_child(__MODULE__, spec)
    |> log(id)
  end

  def finish_switch_process(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def children() do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def count_children() do
    DynamicSupervisor.count_children(__MODULE__)
  end

  defp log(resp = {:ok, _pid}, id) do
    LT.info(id, "Switch process started for switch with id")
    resp
  end

  defp log({:error, error}, id) do
    LT.warn(error, "Switch process for switch with id #{id} - error while starting")
    {:error, error}
  end

  defp log(error, id) do
    LT.warn(error, "Switch process for switch with id #{id} - error while starting")
  end
end
