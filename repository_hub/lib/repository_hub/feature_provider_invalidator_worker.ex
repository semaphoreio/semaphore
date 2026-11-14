defmodule RepositoryHub.FeatureProviderInvalidatorWorker do
  require Logger

  @doc """
  This module consumes RabbitMQ feature and machine state change events
  and invalidates features and machines caches.
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:repository_hub, :amqp_url),
    service: "repository_hub",
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
    connection_id: RepositoryHub.FeatureProviderInvalidatorWorker

  def features_changed(_message) do
    log("invalidating features")
    reload(reload: true)
  end

  def organization_features_changed(message) do
    event = InternalApi.Feature.OrganizationFeaturesChanged.decode(message)
    log("invalidating features for org #{event.org_id}")
    reload(reload: true, param: event.org_id)
  end

  # A failed reload keeps the last known flags (or fails fast while the
  # breaker is open); crashing the consumer wouldn't make FeatureHub answer.
  defp reload(opts) do
    case FeatureProvider.list_features(opts) do
      {:ok, _} -> :ok
      {:error, reason} -> log("reload failed: #{inspect(reason)}")
    end

    :ok
  end

  defp log(message) do
    Logger.info("[FEATURE PROVIDER INVALIDATOR WORKER] #{message}")
  end
end
