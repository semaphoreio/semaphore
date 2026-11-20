defmodule Audit.ConsumerTest do
  use Support.DataCase

  alias InternalApi, as: IA
  alias InternalApi.Audit.Event.{Resource, Operation, Medium}

  test "consuming events" do
    stub_user()
    stub_feature()

    org_id = Ecto.UUID.generate()

    Audit.Consumer.handle_message(secret_event(org_id))

    events = Audit.Event.all(%{org_id: org_id})

    assert length(events) == 1
    assert Enum.at(events, 0).medium == Medium.value(:API)
  end

  test "consuming events with MCP medium" do
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
        medium: Medium.value(:MCP)
      )
      |> IA.Audit.Event.encode()

    Audit.Consumer.handle_message(event)

    events = Audit.Event.all(%{org_id: org_id})

    assert length(events) == 1
    assert Enum.at(events, 0).medium == Medium.value(:MCP)
  end

  test "stores an event right after audit_logs is turned on for an organization" do
    stub_user()
    stub_feature(:HIDDEN)

    org_id = Ecto.UUID.generate()

    Audit.Consumer.handle_message(secret_event(org_id))
    assert Audit.Event.all(%{org_id: org_id}) == []

    stub_feature(:ENABLED)

    Audit.Consumer.handle_message(secret_event(org_id))
    assert Audit.Event.all(%{org_id: org_id}) == []

    IA.Feature.OrganizationFeaturesChanged.new(org_id: org_id)
    |> IA.Feature.OrganizationFeaturesChanged.encode()
    |> Audit.FeatureProviderInvalidatorWorker.organization_features_changed()

    Audit.Consumer.handle_message(secret_event(org_id))
    assert length(Audit.Event.all(%{org_id: org_id})) == 1
  end

  defp secret_event(org_id) do
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
  end
end
