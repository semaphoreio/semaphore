defmodule TaskApiReferent.Initializator.Command do
  @moduledoc """
  Initializes Command's state in Command Agent
  """

  alias TaskApiReferent.Service

  # Sets initial state for every Command
  # Returns List of initialized Commands' ids
  def init_commands(command_type, commands) do
    command_ids =
    Enum.map(commands, fn(cmd) -> init_command(command_type, cmd) end)
    {:ok, command_ids}
  end

  # Sets Command's state in CommandAgent
  # Returns initialized Command's id
  defp init_command(command_type, cmd) do
    command_id = UUID.uuid4()
    add_to_command_agent(command_id, command_type, cmd)
    command_id
  end

  defp add_to_command_agent(command_id, command_type, cmd) do
    command_state = %{type: command_type, command: cmd, execution_result: nil}
    Service.Command.set(command_id, command_state)
  end

end
