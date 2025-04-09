defmodule Guard.Events.OrganizationDeleted do
  @moduledoc """
  Event emitted when an organization is deleted.
  """

  @spec publish(String.t(), Keyword.t()) :: :ok
  def publish(organization_id, opts \\ []) do
    event =
      InternalApi.Organization.OrganizationDeleted.new(
        org_id: organization_id,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.Organization.OrganizationDeleted.encode(event)

    exchange_name = "organization_exchange"
    routing_key = if opts[:soft_delete], do: "soft_deleted", else: "deleted"

    {:ok, channel} = AMQP.Application.get_channel(:organization)
    :ok = AMQP.Basic.publish(channel, exchange_name, routing_key, message)
  end
end
