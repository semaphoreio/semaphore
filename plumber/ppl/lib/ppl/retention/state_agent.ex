defmodule Ppl.Retention.StateAgent do
  @moduledoc """
  Manages state for all retention workers.
  """

  use Agent

  alias Ppl.Retention.Deleter
  alias Ppl.Retention.Policy

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get_state(worker_module) do
    Agent.get_and_update(__MODULE__, fn states ->
      case Map.fetch(states, worker_module) do
        {:ok, state} ->
          {state, states}

        :error ->
          state = init_state(worker_module)
          {state, Map.put(states, worker_module, state)}
      end
    end)
  end

  def put_state(worker_module, state) do
    Agent.update(__MODULE__, &Map.put(&1, worker_module, state))
  end

  def update_state(worker_module, fun) do
    Agent.get_and_update(__MODULE__, fn states ->
      current =
        case Map.fetch(states, worker_module) do
          {:ok, state} -> state
          :error -> init_state(worker_module)
        end

      new_state = fun.(current)
      {new_state, Map.put(states, worker_module, new_state)}
    end)
  end

  defp init_state(Policy.Worker), do: Policy.State.from_env(Policy.Worker)
  defp init_state(Deleter.Worker), do: Deleter.State.from_env(Deleter.Worker)
end
