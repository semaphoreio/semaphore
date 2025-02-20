defmodule Guard.Events.FavoriteCreated do
  require Logger

  @routing_key "favorite_created"

  @spec publish(InternalApi.User.Favorite.t(), String.t()) :: :ok
  def publish(favorite, exchange_name) do
    event =
      InternalApi.User.FavoriteCreated.new(
        favorite: favorite,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.User.FavoriteCreated.encode(event)

    {:ok, channel} = AMQP.Application.get_channel(:user)

    Tackle.Exchange.create(channel, exchange_name)

    Logger.info("Publishing favorite_created event for user #{favorite.user_id}")

    :ok = Tackle.Exchange.publish(channel, exchange_name, message, @routing_key)
  end
end
