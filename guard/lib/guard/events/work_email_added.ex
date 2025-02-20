defmodule Guard.Events.WorkEmailAdded do
  @routing_key "work_email_added"

  @spec publish(String.t(), String.t(), String.t()) :: :ok
  def publish(user, old_email, exchange_name) do
    event =
      InternalApi.User.WorkEmailAdded.new(
        user_id: user.id,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second)),
        old_email: old_email,
        new_email: user.email
      )

    message = InternalApi.User.WorkEmailAdded.encode(event)
    {:ok, channel} = AMQP.Application.get_channel(:user)

    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, @routing_key)
  end
end
