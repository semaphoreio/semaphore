defmodule Support.TestConsumer do
  @moduledoc """
  Test consumer module for testing purposes.
  Created for testing message processing in the consumer without the
  need of waiting an unknown period of time for the message to be
  processed in the real consumer. Avoiding flaky tests.
  """

  def create_test_consumer(receiver_pid, url, exchange, routing_key, service, consumer_module) do
    unique_module_name =
      Module.concat(Support.TestConsumer, "Consumer_#{Ecto.UUID.generate()}")

    Module.create(
      unique_module_name,
      quote do
        require Logger

        use Tackle.Consumer,
          url: unquote(url),
          exchange: unquote(exchange),
          routing_key: unquote(routing_key),
          service: unquote(service)

        def handle_message(message) do
          Logger.debug("Test Consumer received message")

          if function_exported?(unquote(consumer_module), :handle_message, 1),
            do: unquote(consumer_module).handle_message(message)

          send(unquote(receiver_pid), {:ok, unquote(consumer_module)})
        end
      end,
      Macro.Env.location(__ENV__)
    )
  end
end
