defmodule Rbac.Events.UserCreated do
  @spec publish(String.t(), boolean) :: :ok
  def publish(user_id, invited) do
    event = %InternalApi.User.UserCreated{
      user_id: user_id,
      invited: invited,
      timestamp: %Google.Protobuf.Timestamp{
        seconds: DateTime.utc_now() |> DateTime.to_unix(:second)
      }
    }

    message = InternalApi.User.UserCreated.encode(event)

    exchange_name = "user_exchange"
    routing_key = "created"

    {:ok, channel} = AMQP.Application.get_channel(:user)
    Tackle.Exchange.create(channel, exchange_name)

    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

    :ok
  end
end
