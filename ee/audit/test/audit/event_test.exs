defmodule Audit.EventTest do
  use Support.DataCase

  alias InternalApi.Audit.Event.{Resource, Operation, Medium}

  test "creating events" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    operation_id = Ecto.UUID.generate()
    resource_id = Ecto.UUID.generate()
    resource_name = "my-secret"

    {:ok, event} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        resource_id: resource_id,
        resource_name: resource_name,
        org_id: org_id,
        user_id: user_id,
        username: "hello",
        ip_address: "127.0.0.1",
        operation_id: operation_id,
        timestamp: DateTime.from_unix!(0),
        metadata: %{"hello" => "world"},
        medium: Medium.value(:Web)
      })

    assert event.resource == Resource.value(:Secret)
    assert event.operation == Operation.value(:Added)
    assert event.resource_id == resource_id
    assert event.resource_name == resource_name
    assert event.org_id == org_id
    assert event.user_id == user_id
    assert event.operation_id == operation_id
    assert event.ip_address == "127.0.0.1"
    assert event.username == "hello"
    assert event.metadata == %{"hello" => "world"}
    assert event.medium == Medium.value(:Web)
  end

  test "listing events" do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        org_id: org_id,
        user_id: user_id,
        username: "hello",
        ip_address: "127.0.0.1",
        operation_id: Ecto.UUID.generate(),
        timestamp: DateTime.from_unix!(100),
        medium: Medium.value(:Web)
      })

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Removed),
        org_id: org_id,
        user_id: user_id,
        username: "hello",
        ip_address: "127.0.0.1",
        operation_id: Ecto.UUID.generate(),
        timestamp: DateTime.from_unix!(200),
        medium: Medium.value(:Web)
      })

    {:ok, _} =
      Audit.Event.create(%{
        resource: Resource.value(:Secret),
        operation: Operation.value(:Removed),
        org_id: Ecto.UUID.generate(),
        user_id: user_id,
        username: "hello",
        ip_address: "127.0.0.1",
        operation_id: Ecto.UUID.generate(),
        timestamp: DateTime.from_unix!(300),
        medium: Medium.value(:Web)
      })

    events = Audit.Event.all(%{org_id: org_id})
    assert length(events) == 2

    assert Enum.at(events, 0).resource == Resource.value(:Secret)
    assert Enum.at(events, 0).operation == Operation.value(:Added)
    assert Enum.at(events, 0).org_id == org_id
    assert Enum.at(events, 0).user_id == user_id
    assert Enum.at(events, 0).operation_id != ""
    assert Enum.at(events, 0).username == "hello"
    assert Enum.at(events, 0).medium == Medium.value(:Web)

    assert Enum.at(events, 1).resource == Resource.value(:Secret)
    assert Enum.at(events, 1).operation == Operation.value(:Removed)
    assert Enum.at(events, 1).org_id == org_id
    assert Enum.at(events, 1).user_id == user_id
    assert Enum.at(events, 0).operation_id != ""
    assert Enum.at(events, 1).username == "hello"
    assert Enum.at(events, 1).medium == Medium.value(:Web)
  end
end
