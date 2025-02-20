defmodule Rbac.Utils.Counter do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok, 0}
  end

  def handle_call({:increment, value}, _from, state) do
    {:reply, state + value, state + value}
  end

  def handle_call(:get_count, _from, state) do
    {:reply, state, state}
  end
end
