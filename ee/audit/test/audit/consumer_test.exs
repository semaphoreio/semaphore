defmodule Audit.ConsumerTest do
  use Support.DataCase

  alias InternalApi, as: IA
  alias InternalApi.Audit.Event.{Resource, Operation, Medium}

  test "consuming events" do
    stub_user()
    stub_feature()

    org_id = Ecto.UUID.generate()

    event =
      IA.Audit.Event.new(
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        org_id: org_id,
        user_id: Ecto.UUID.generate(),
        ip_address: "2.3.4.5",
        operation_id: Ecto.UUID.generate(),
        timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
        resource_id: Ecto.UUID.generate(),
        resource_name: "my-secret",
        metadata: Poison.encode!(%{"hello" => "world"}),
        medium: Medium.value(:API)
      )
      |> IA.Audit.Event.encode()

    Audit.Consumer.handle_message(event)

    events = Audit.Event.all(%{org_id: org_id})

    assert length(events) == 1
  end
end
