defmodule Guard.Events.OrganizationSuspensionCreated do
  @moduledoc """
  Event emitted when a new suspension is created for an organization.
  """

  @spec publish(String.t(), atom()) :: :ok
  def publish(organization_id, reason) do
    event =
      InternalApi.Organization.OrganizationSuspensionCreated.new(
        org_id: organization_id,
        reason: InternalApi.Organization.Suspension.Reason.value(reason),
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.Organization.OrganizationSuspensionCreated.encode(event)

    exchange_name = "organization_exchange"
    routing_key = "suspension_created"

    {:ok, channel} = AMQP.Application.get_channel(:organization)
    Tackle.Exchange.create(channel, exchange_name)

    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

    :ok
  end
end
