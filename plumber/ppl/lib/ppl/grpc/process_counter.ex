defmodule Ppl.Grpc.ProcessCounter do
  @moduledoc """
  Holds count of all registered processes.

  Multiple instances of this module can run simultaneously,
  each counting particular type of processes.

  ProcessCounter is started with its type and limit.

      start_link(type: :describe, limit: 15)

  or when started under supervisor

      {ProcessCounter, type: :describe, limit: 15}

  Process registers itself by calling `register/1` operation.
  Process is deregistered automatically on termination.
  """

  use GenServer

  @metric_name "Ppl.ProcessCounter"

  def start_link(args = [type: type, limit: _]) do
    LogTee.info(type, "#{__MODULE__}: type")

    GenServer.start_link(__MODULE__, args, name: name(type))
  end

  @doc """
  Process calls this operation to register itself with counter of specified `type`.

  Operation returns `:accept` if count is below "count_limit"
  or `:reject` otherwise.
  """
  def register(type) do
    type
    |> name()
    |> GenServer.call({:register, self()})
    |> decide()
  end

  def count(type), do: GenServer.call(name(type), :count)

  def set_limit(type, limit), do: GenServer.call(name(type), {:set_limit, limit})

  #########################################

  @impl true
  def init([type: type, limit: limit]) do
    {:ok, %{pids: %{}, type: type, limit: limit}}
  end

  @impl true
  def handle_call(:count, _from, state), do: {:reply, map_size(state.pids), state}

  @impl true
  def handle_call({:register, pid}, _from, state) do
    ref = Process.monitor(pid)

    pid
    |> Process.alive?()
    |> do_register(state, pid, ref)
  end

  @impl true
  def handle_call({:set_limit, limit}, _from, state) do
    {:reply, state.limit, Map.put(state, :limit, limit)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state = %{pids: pids}) do
    {pid, reason}
    |> LogTee.debug("PROCESS TERMINATED")

    new_pids = Map.delete(pids, pid)
    {:noreply, Map.put(state, :pids, new_pids)}
  end

  #########################################

  defp do_register(_alive? = true, state, pid, ref) do
    new_pids = Map.put(state.pids, pid, ref)

    count = map_size(new_pids)
    Watchman.submit({@metric_name, [state.type, :current_state]}, count, :timing)

    {:reply, {count, state.limit}, Map.put(state, :pids, new_pids)}
  end

  defp do_register(_alive? = false, state, _pid, _ref) do
    {:reply, :process_died, state}
  end

  defp name(type), do: :"#{__MODULE__}_#{type}"

  defp decide({count, limit}) when count < limit, do: :accept
  defp decide({_count, _limit}), do: :reject
  defp decide(:process_died), do: :reject
end
