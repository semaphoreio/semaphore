defmodule Guard.Events.ConfigModified do
  @moduledoc """
  Event emitted when an instance config is modified.
  """

  @spec publish(InternalApi.InstanceConfig.ConfigType.t()) :: :ok
  def publish(type) do
    event =
      InternalApi.InstanceConfig.ConfigModified.new(
        type: type,
        timestamp:
          Google.Protobuf.Timestamp.new(seconds: DateTime.utc_now() |> DateTime.to_unix(:second))
      )

    message = InternalApi.InstanceConfig.ConfigModified.encode(event)

    exchange_name = "instance_config_exchange"
    routing_key = "modified"

    {:ok, channel} = AMQP.Application.get_channel(:instance_config)
    Tackle.Exchange.create(channel, exchange_name)

    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)

    :ok
  end
end
