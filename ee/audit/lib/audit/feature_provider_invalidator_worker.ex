defmodule Audit.FeatureProviderInvalidatorWorker do
  require Logger

  @doc """
  This module consumes RabbitMQ feature and machine state change events
  and invalidates features and machines caches.
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:audit, :amqp_url),
    service: "audit",
    routes: [
      {"feature_exchange", "features_changed", :features_changed},
      {"feature_exchange", "organization_features_changed", :organization_features_changed}
    ],
    # This queue is used to consume events from the feature exchange.
    # It is declared as non-durable, auto-delete and exclusive.
    # This means that the queue will be deleted when the consumer disconnects.
    # This is the desired behavior, because these events are used to invalidate pod-level caches.
    queue: :dynamic,
    queue_opts: [
      durable: false,
      auto_delete: true,
      exclusive: true
    ],
    connection_id: Audit.FeatureProviderInvalidatorWorker

  def features_changed(_message) do
    log("invalidating features")
    {:ok, _} = FeatureProvider.list_features(reload: true)
    :ok
  end

  def organization_features_changed(message) do
    event = InternalApi.Feature.OrganizationFeaturesChanged.decode(message)
    log("invalidating features for org #{event.org_id}")
    {:ok, _} = FeatureProvider.list_features(reload: true, param: event.org_id)
    :ok
  end

  defp log(message) do
    Logger.info("[FEATURE PROVIDER INVALIDATOR WORKER] #{message}")
  end
end
