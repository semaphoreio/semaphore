defmodule Guard.Events.OrganizationCreated do
  @moduledoc """
  Event emitted when an organization is created.
  """

  @spec publish(String.t()) :: :ok
  def publish(organization_id) do
    event =
      InternalApi.Organization.OrganizationCreated.new(
        org_id: organization_id,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.Organization.OrganizationCreated.encode(event)

    exchange_name = "organization_exchange"
    routing_key = "created"

    {:ok, channel} = AMQP.Application.get_channel(:organization)
    :ok = AMQP.Basic.publish(channel, exchange_name, routing_key, message)
  end
end
