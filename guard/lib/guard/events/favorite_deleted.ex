defmodule Guard.Events.FavoriteDeleted do
  require Logger

  @routing_key "favorite_deleted"

  @spec publish(InternalApi.User.Favorite.t(), String.t()) :: :ok
  def publish(favorite, exchange_name) do
    event =
      InternalApi.User.FavoriteDeleted.new(
        favorite: favorite,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.User.FavoriteDeleted.encode(event)

    {:ok, channel} = AMQP.Application.get_channel(:user)

    Tackle.Exchange.create(channel, exchange_name)

    Logger.info("Publishing favorite_deleted event for user #{favorite.user_id}")

    :ok = Tackle.Exchange.publish(channel, exchange_name, message, @routing_key)
  end
end
