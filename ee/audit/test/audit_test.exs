defmodule AuditTest do
  use Support.DataCase

  alias InternalApi.Audit.Event.{Resource, Operation, Medium}

  test "it collects project creation events" do
    stub_user()
    stub_feature()

    event =
      IA.Audit.Event.new(
        resource: Resource.value(:Secret),
        operation: Operation.value(:Added),
        org_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        operation_id: Ecto.UUID.generate(),
        ip_address: "1.3.5.8",
        timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
        resource_id: Ecto.UUID.generate(),
        resource_name: "my-secret",
        metadata: Poison.encode!(%{"hello" => "world"}),
        medium: Medium.value(:API)
      )

    publish(event)

    # wait for the consumer to consume it
    :timer.sleep(2000)

    res = list(event.org_id)

    assert length(res.events) == 1

    response_event = Enum.at(res.events, 0)

    assert response_event.resource == :Secret
    assert response_event.operation == :Added
    assert response_event.org_id == event.org_id
    assert response_event.user_id == event.user_id
    assert response_event.username == "tester"
    assert response_event.ip_address == event.ip_address
    assert response_event.operation_id == event.operation_id
    assert response_event.timestamp == event.timestamp
    assert response_event.metadata == event.metadata
    assert response_event.resource_id == event.resource_id
    assert response_event.resource_name == event.resource_name
    assert response_event.medium == :API
  end

  defp list(org_id) do
    request = InternalApi.Audit.ListRequest.new(org_id: org_id)
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, res} = InternalApi.Audit.AuditService.Stub.list(channel, request)

    res
  end

  defp publish(event) do
    url = Application.get_env(:audit, :amqp_url)
    options = %{url: url, exchange: "audit", routing_key: "log"}

    Tackle.publish(IA.Audit.Event.encode(event), options)
  end
end
