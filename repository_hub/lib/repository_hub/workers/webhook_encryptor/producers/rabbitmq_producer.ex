defmodule RepositoryHub.WebhookEncryptor.RabbitMQProducer do
  @moduledoc """
  RabbitMQ producer for webhook encryptor.

  Consumes organization_features_changed events from the feature_exchange
  and then forwards them to the GenStage processing pipeline.

  For simplicity, it currently rejects failed messages.
  """

  @service_name "repositoryhub.webhook_encryptor"
  @routing_key "organization_features_changed"
  @service_exchange "#{@service_name}.#{@routing_key}"
  @service_queue @service_exchange
  @remote_exchange "feature_exchange"
  @prefetch_count 1

  @service_exchange_opts [
    durable: true,
    auto_delete: true
  ]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenStage.start_link(BroadwayRabbitMQ.Producer, producer_args(args), name: __MODULE__)
  end

  defp producer_args(args) do
    [
      # connection config
      connection: Application.get_env(:repository_hub, :amqp_url),
      name: @service_name,
      qos: [prefetch_count: args[:prefetch_count] || @prefetch_count],
      # topology config
      after_connect: fn channel ->
        with :ok <- AMQP.Exchange.direct(channel, @service_exchange, @service_exchange_opts),
             :ok <- AMQP.Exchange.direct(channel, @remote_exchange, durable: true) do
          AMQP.Exchange.bind(channel, @service_exchange, @remote_exchange, routing_key: @routing_key)
        end
      end,
      # queue config
      queue: @service_queue,
      declare: [
        durable: true,
        auto_delete: true
      ],
      bindings: [
        {@service_exchange, [routing_key: @routing_key]}
      ],
      # acknowledge config
      on_success: :ack,
      on_failure: :reject
    ]
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
end
