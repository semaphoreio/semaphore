defmodule Dashboardhub.Events.Publisher do
  def publish(message, options) do
    exchange_name = options[:exchange] || "dashboard_exchange"
    channel_name = options[:channel]
    routing_key = options[:routing_key]

    {:ok, channel} = AMQP.Application.get_channel(channel_name)

    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
  end
end
