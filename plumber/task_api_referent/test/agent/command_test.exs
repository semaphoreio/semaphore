defmodule TaskApiReferent.Agent.CommandTest do
  use ExUnit.Case

  alias TaskApiReferent.Agent

  setup_all do
    command = %{command: "dir", execution_result: "", type: :JOB}
    Agent.Command.set(:test_command, command)

    {:ok, [command: command]}
  end

  test "get - providing valid command_id it should return existing commands's state Map", context do
    {:ok, command} = Agent.Command.get(:test_command)
    assert Map.equal?(command, context[:command])
  end

  test "get - providing invalid command_id should return :error with error message" do
    command_id = :invalid_command_id
    assert {:error, _} = Agent.Command.get(command_id)
  end

  test "set - providing command_id should set a new value in Agent's state Map" do
    command_id = UUID.uuid4()
    command = %{command: "echo hello", execution_result: ""}

    assert {:ok, _} = Agent.Command.set(command_id, command)

    {:ok, result} = Agent.Command.get(command_id)
    assert Map.equal?(result, command)
  end
end
