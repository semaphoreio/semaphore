defmodule Looper.Publisher.AMQPTest do
  use ExUnit.Case

  defmodule Consumer do
    def amqp_url, do: System.get_env("RABBITMQ_URL")

    use Tackle.Consumer,
      url: amqp_url(),
      exchange: "AMQPTest",
      routing_key: "running",
      service: "test"

    def handle_message("#PID" <> string) do
      pid = string |> :erlang.binary_to_list |> :erlang.list_to_pid
      send(pid, :done)
    end
  end

  test "Happy path test" do
    exchange = "AMQPTest"

    {:ok, consumer} = Consumer.start_link()
    {:ok, _publisher} = Looper.Publisher.AMQP.start_link(Consumer.amqp_url())

    :timer.sleep(:timer.seconds(1))

    %{exchange: exchange, routing_key: "running", message: inspect(self())}
    |> Looper.Publisher.AMQP.publish()

    receive do
      :done ->
        :pass
    after
      :timer.seconds(5) ->
        assert false
    end

    Looper.Publisher.AMQP.stop()
    GenServer.stop(consumer)
  end
end
