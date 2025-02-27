defmodule Rbac.Events.UserLeftOrganization do
  def publish(user_id, org_id, join_time \\ DateTime.utc_now()) do
    event = %InternalApi.User.UserLeftOrganization{
      user_id: user_id,
      org_id: org_id,
      timestamp: %Google.Protobuf.Timestamp{seconds: join_time |> DateTime.to_unix(:second)}
    }

    message = InternalApi.User.UserLeftOrganization.encode(event)

    exchange_name = "user_exchange"
    routing_key = "user_left_organization"
    {:ok, channel} = AMQP.Application.get_channel(:user)
    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
  end
end
