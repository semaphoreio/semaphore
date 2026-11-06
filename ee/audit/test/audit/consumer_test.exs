defmodule Audit.ConsumerTest do
  use Support.DataCase

  alias InternalApi, as: IA
  alias InternalApi.Audit.Event.{Resource, Operation, Medium}

  test "consuming events" do
    stub_user()
    stub_feature()

    org_id = Ecto.UUID.generate()

    Audit.Consumer.handle_message(encode_event(org_id, :API))

    events = Audit.Event.all(%{org_id: org_id})

    assert length(events) == 1
    assert Enum.at(events, 0).medium == Medium.value(:API)
  end

  test "consuming events with MCP medium" do
    stub_user()
    stub_feature()

    org_id = Ecto.UUID.generate()

    Audit.Consumer.handle_message(encode_event(org_id, :MCP))

    events = Audit.Event.all(%{org_id: org_id})

    assert length(events) == 1
    assert Enum.at(events, 0).medium == Medium.value(:MCP)
  end

  test "keeps storing events when a feature reload fails" do
    stub_user()
    stub_feature()

    org_id = Ecto.UUID.generate()
    assert FeatureProvider.feature_enabled?(:audit_logs, param: org_id)

    # The feature service fails while a feature change event is handled, then recovers.
    stub_failing_feature_service()
    organization_features_changed(org_id)
    stub_feature()

    Audit.Consumer.handle_message(encode_event(org_id, :API))

    assert length(Audit.Event.all(%{org_id: org_id})) == 1
  end

  defp organization_features_changed(org_id) do
    [org_id: org_id]
    |> IA.Feature.OrganizationFeaturesChanged.new()
    |> IA.Feature.OrganizationFeaturesChanged.encode()
    |> Audit.FeatureProviderInvalidatorWorker.organization_features_changed()
  end

  defp encode_event(org_id, medium) do
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
      medium: Medium.value(medium)
    )
    |> IA.Audit.Event.encode()
  end
end
