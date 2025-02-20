defmodule Guard.Events.OrganizationBlocked do
  @moduledoc """
  Event emitted when an organization is blocked (suspended and/or unverified).
  """

  @spec publish(String.t(), atom()) :: :ok
  def publish(organization_id, reason) do
    event =
      InternalApi.Organization.OrganizationBlocked.new(
        org_id: organization_id,
        reason: InternalApi.Organization.Suspension.Reason.value(reason),
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.Organization.OrganizationBlocked.encode(event)

    exchange_name = "organization_exchange"
    routing_key = "blocked"

    {:ok, channel} = AMQP.Application.get_channel(:organization)
    Tackle.Exchange.create(channel, exchange_name)

    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

    :ok
  end
end
