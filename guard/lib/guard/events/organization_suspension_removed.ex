defmodule Guard.Events.OrganizationSuspensionRemoved do
  @moduledoc """
  Event emitted when a suspension is removed from an organization.
  """

  @spec publish(String.t(), atom()) :: :ok
  def publish(organization_id, reason) do
    event =
      InternalApi.Organization.OrganizationSuspensionRemoved.new(
        org_id: organization_id,
        reason: InternalApi.Organization.Suspension.Reason.value(reason),
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.Organization.OrganizationSuspensionRemoved.encode(event)

    exchange_name = "organization_exchange"
    routing_key = "suspension_removed"

    {:ok, channel} = AMQP.Application.get_channel(:organization)
    Tackle.Exchange.create(channel, exchange_name)

    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

    :ok
  end
end
