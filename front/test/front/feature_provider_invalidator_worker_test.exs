defmodule Front.FeatureProviderInvalidatorWorkerTest do
  use ExUnit.Case, async: false

  alias Front.Clients.Billing
  alias Front.FeatureProviderInvalidatorWorker
  alias InternalApi.Billing.ListAddonsRequest
  alias InternalApi.Feature.OrganizationFeaturesChanged

  test "organization_features_changed drops the cached add-ons list of that org only" do
    org_id = Ecto.UUID.generate()
    other_org_id = Ecto.UUID.generate()
    key = Billing.cache_key(:list_addons, %ListAddonsRequest{org_id: org_id})
    other_key = Billing.cache_key(:list_addons, %ListAddonsRequest{org_id: other_org_id})

    Front.Cache.set(key, :stale)
    Front.Cache.set(other_key, :other)

    message = OrganizationFeaturesChanged.encode(%OrganizationFeaturesChanged{org_id: org_id})
    assert :ok = FeatureProviderInvalidatorWorker.organization_features_changed(message)

    assert {:not_cached, ^key} = Front.Cache.get(key)
    assert {:ok, :other} = Front.Cache.get(other_key)
  end
end
