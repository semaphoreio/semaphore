defmodule Support.Events.TestConsumer do
  def create_test_consumer(pid, url, exchange, routing_key, service, matching_key) do
    unique_module_name =
      Module.concat(Support.Events.TestConsumer, "Consumer_#{Ecto.UUID.generate()}")

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
          send(unquote(pid), {unquote(matching_key), message})
        end
      end,
      Macro.Env.location(__ENV__)
    )
  end
end
