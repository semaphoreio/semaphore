defmodule TaskApiReferent.Agent.Command do
  @moduledoc """
  Elixir Agent used to persist state of every Command

  example:
    %{command_id:
      %{type: :EPILOGUE,
        command: "command that will be executed",
        execution_result: "console output for the command",
        result: :PASSED}
    }

  type: Atom, value can be: :EPILOGUE, :PROLOGUE, :JOB
  """

  use Agent

  @doc "Starts an agent and initializes state map"
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    Agent.start_link(fn -> %{} end, opts)
  end

  @doc "Gets Commands's state Map"
  def get(command_id) do
    Agent.get(__MODULE__, fn map ->
      case Map.get(map, command_id) do
        nil -> {:error, "'command_id' parameter that you provided doesn't match any command."}
        state -> {:ok, state}
      end
    end)
  end

  @doc "Sets Command's state Map"
  def set(command_id, value) do
    Agent.get_and_update(__MODULE__, fn map ->
      new_state = Map.put(map, command_id, value)
      {{:ok, {command_id, value}}, new_state}
    end)
  end
end
