defmodule Test.TestGenServer do
  @moduledoc """
  GenServer for testing modeled to resamble the SwitchTriggerProcess and
  TargetTriggerProcess GenServers.
  """
  use GenServer, restart: :transient
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: {:global, name})
  end

  def init(name) do
    Process.send_after(self(), :wait_a_little, 1_000)
    {:ok, %{name: name}}
  end

  def handle_info(:wait_a_little, %{name: name}) do
    Logger.info("TestGenServer #{name} waiting for 1 second.")
    Process.send_after(self(), :wait_a_little, 1_000)
    {:noreply, %{name: name}}
  end

  def handle_cast({:terminate, reason}, %{name: name}) do
    Logger.info("TestGenServer #{name} is terminating with reason #{reason}.")
    {:stop, reason, %{name: name}}
  end
end
