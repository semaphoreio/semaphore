defmodule TaskApiReferent.Service.Command do
  @moduledoc """
  Service Layer delegating calls to the CommandAgent
  """

  alias TaskApiReferent.Agent

  @doc "Gets a Command's state from the Command Agent"
  def get(command_id) do
    Agent.Command.get(command_id)
  end

  @doc "Sets the Command state in Command Agent"
  def set(command_id, state) do
    Agent.Command.set(command_id, state)
  end

  @doc "Sets one of the properties in Command's state Map"
  def set_property(command_id, property_name, property_value) do
    with {:ok, command}  <- get(command_id),
         updated_command <- Map.put(command, property_name, property_value),
    do: set(command_id, updated_command)
  end

  @doc "Gets one of the properties from Command's state Map"
  def get_property(command_id, property_name) do
    with {:ok, command} <- get(command_id),
         property_value <- Map.get(command, property_name),
    do: {:ok, property_value}
  end
end
