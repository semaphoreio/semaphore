defmodule Guard.Events.UserDeleted do
  @spec publish(String.t(), String.t(), String.t()) :: :ok
  def publish(user_id, exchange_name, routing_key) do
    event =
      InternalApi.User.UserDeleted.new(
        user_id: user_id,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.User.UserDeleted.encode(event)

    {:ok, channel} = AMQP.Application.get_channel(:user)

    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
  end
end
