defmodule Guard.Events.OrganizationUnblocked do
  @moduledoc """
  Event emitted when an organization is unblocked (no more active suspensions).
  """

  @spec publish(String.t()) :: :ok
  def publish(organization_id) do
    event =
      InternalApi.Organization.OrganizationUnblocked.new(
        org_id: organization_id,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.Organization.OrganizationUnblocked.encode(event)

    exchange_name = "organization_exchange"
    routing_key = "unblocked"

    {:ok, channel} = AMQP.Application.get_channel(:organization)
    Tackle.Exchange.create(channel, exchange_name)

    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

    :ok
  end
end
