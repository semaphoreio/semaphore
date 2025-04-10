defmodule Guard.Events.OrganizationDeleted do
  @moduledoc """
  Event emitted when an organization is deleted.
  """

  @spec publish(String.t(), Keyword.t()) :: :ok | {:error, :missing_event_type}
  def publish(organization_id, opts) do
    case opts[:type] do
      :soft_delete -> do_publish(organization_id, "soft_deleted")
      :hard_delete -> do_publish(organization_id, "deleted")
      nil -> {:error, :missing_event_type}
      _ -> {:error, :invalid_event_type}
    end
  end

  defp do_publish(organization_id, routing_key) do
    event =
      InternalApi.Organization.OrganizationDeleted.new(
        org_id: organization_id,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.Organization.OrganizationDeleted.encode(event)

    exchange_name = "organization_exchange"

    {:ok, channel} = AMQP.Application.get_channel(:organization)
    :ok = AMQP.Basic.publish(channel, "organization_exchange", routing_key, message)
  end
end
