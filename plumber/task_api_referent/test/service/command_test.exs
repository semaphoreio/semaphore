defmodule TaskApiReferent.Service.CommandTest do
  use ExUnit.Case

  alias TaskApiReferent.Service

  require UUID

  setup_all do
    command = %{state: :FINISHED, result: :FAILED, jobs: []}

    Service.Command.set(:valid_command, command)
    {:ok, [valid_command: command]}
  end

  test "set_property - providing command_id, property_name and property_value, it should add property_name:property_value pair in CommandAgent" do
    command_id = UUID.uuid4()
    command = %{}
    Service.Command.set(command_id, command)

    Service.Command.set_property(command_id, :type, :REPO)

    {:ok, command} = Service.Command.get(command_id)
    assert :REPO == Map.get(command, :type)
  end

  test "get_property - providing command_id, property_name, it should return property_value from CommandAgent" do
    command_id = UUID.uuid4()
    command = %{type: :REPO}
    Service.Command.set(command_id, command)

    {:ok, property_value} = Service.Command.get_property(command_id, :type)
    assert property_value == :REPO
  end
end
