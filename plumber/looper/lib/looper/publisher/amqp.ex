defmodule Looper.Publisher.AMQP do
  @moduledoc """
  Efficiently publish messages to RabbitMQ.
  """

  use GenServer

  def start_link(url) do
    GenServer.start_link(__MODULE__, url, name: __MODULE__)
  end

  def stop, do: GenServer.stop(__MODULE__)

  def publish(data) when is_map(data) do
    GenServer.call(__MODULE__, {:publish, data})
  end

  @impl true
  def init(url) do
    {:ok, connection} = AMQP.Connection.open(url)
    {:ok, channel} = AMQP.Channel.open(connection)

    {:ok, %{url: url, channel: channel, exchanges: []}}
  end

  # Called by :sys.get_status/1,2 (and therefore by the crash/termination
  # report gen_server writes to the logger) to build the status term. The
  # default implementation would dump `state` as-is, including the raw AMQP
  # url (with embedded credentials). Only the reported view is changed here;
  # the actual GenServer state used by init/handle_call is untouched.
  @impl true
  def format_status(_reason, [_pdict, state]) do
    [{:data, [{'State', %{state | url: "[FILTERED]"}}]}]
  end

  @impl true
  def handle_call({:publish, %{exchange: exchange, routing_key: routing_key, message: message}},
          _from, state = %{channel: channel, exchanges: exchanges}) do

    exchanges = exchange_exists(exchanges, channel, exchange)
    state = Map.put(state, :exchanges, exchanges)

    :ok = AMQP.Basic.publish(channel, exchange, routing_key, message, persistent: true)

    # Even this call returns no useful info it should not be converted to cast
    # because call will wait for message to be successfully sent or crash.
    {:reply, :ok, state}
  end

  defp exchange_exists(exchanges, channel, exchange) do
    if Enum.find(exchanges, fn name -> name == exchange end) do
      exchanges
    else
      :ok = AMQP.Exchange.direct(channel, exchange, durable: true)
      [exchange | exchanges]
    end
  end
end
