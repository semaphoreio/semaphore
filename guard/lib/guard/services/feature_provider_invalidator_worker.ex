defmodule Guard.Services.FeatureProviderInvalidatorWorker do
  @doc """
  This module consumes RabbitMQ feature and machine state change events
  and invalidates features and machines caches.
  """

  use Tackle.Consumer,
    url: Application.get_env(:guard, :amqp_url),
    exchange: "feature_exchange",
    routing_key: "organization_features_changed",
    service: "guard",
    queue: :dynamic,
    queue_opts: [
      durable: false,
      auto_delete: true,
      exclusive: true
    ]

  def handle_message(message) do
    event = InternalApi.Feature.OrganizationFeaturesChanged.decode(message)
    FeatureProvider.list_features(invalidate: true, reload: true, param: event.org_id)
    :ok
  end
end
