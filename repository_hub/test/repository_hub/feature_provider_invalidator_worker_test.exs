defmodule RepositoryHub.FeatureProviderInvalidatorWorkerTest do
  use ExUnit.Case, async: false

  import Mock

  alias RepositoryHub.FeatureProviderInvalidatorWorker

  test "features_changed reloads all features" do
    with_mock FeatureProvider, list_features: fn _opts -> {:ok, []} end do
      assert :ok = FeatureProviderInvalidatorWorker.features_changed("")
      assert_called(FeatureProvider.list_features(reload: true))
    end
  end

  test "organization_features_changed reloads the organization's features" do
    org_id = Ecto.UUID.generate()

    message =
      InternalApi.Feature.OrganizationFeaturesChanged.encode(%InternalApi.Feature.OrganizationFeaturesChanged{
        org_id: org_id
      })

    with_mock FeatureProvider, list_features: fn _opts -> {:ok, []} end do
      assert :ok = FeatureProviderInvalidatorWorker.organization_features_changed(message)
      assert_called(FeatureProvider.list_features(reload: true, param: org_id))
    end
  end

  test "a failed reload doesn't crash the consumer" do
    with_mock FeatureProvider, list_features: fn _opts -> {:error, {:not_found, :list_features}} end do
      assert :ok = FeatureProviderInvalidatorWorker.features_changed("")
    end
  end
end
