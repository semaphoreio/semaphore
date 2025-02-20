defmodule PublicAPI.Workers.CacheInvalidator do
  require Logger

  @moduledoc """
  The CacheInvalidator module consumes feature change events and invalidates the in memory cache.
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:public_api, :amqp_url),
    service: "public_api_cache_invalidator",
    routes: [
      {"feature_exchange", "features_changed", :features_changed},
      {"feature_exchange", "organization_features_changed", :organization_features_changed}
    ],
    queue: :dynamic,
    queue_opts: [
      durable: false,
      auto_delete: true,
      exlusive: true
    ]

  def features_changed(_message) do
    Logger.info("Invalidating features")
    {:ok, _} = FeatureProvider.list_features(reload: true)
    :ok
  end

  def organization_features_changed(message) do
    event = InternalApi.Feature.OrganizationFeaturesChanged.decode(message)
    Logger.info("Invalidating features for org #{event.org_id}")
    {:ok, _} = FeatureProvider.list_features(reload: true, param: event.org_id)
    :ok
  end
end
