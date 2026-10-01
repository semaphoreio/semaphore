defmodule PipelinesAPI.FeatureProviderInvalidatorWorker.Test do
  use ExUnit.Case

  alias InternalApi.Feature.{FeaturesChanged, OrganizationFeaturesChanged}
  alias PipelinesAPI.FeatureProviderInvalidatorWorker, as: Worker

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    org = Support.Stubs.DB.first(:organizations)

    {:ok, org_id: org.id}
  end

  test "features_changed invalidates global feature cache" do
    assert feature_state(nil, "deployment_targets") == :enabled

    Support.Stubs.Feature.setup_feature("deployment_targets", state: :HIDDEN, quantity: 0)
    assert feature_state(nil, "deployment_targets") == :enabled

    callback_message = %FeaturesChanged{} |> FeaturesChanged.encode()

    assert :ok = Worker.features_changed(callback_message)
    assert feature_state(nil, "deployment_targets") == :disabled
  end

  test "organization_features_changed invalidates organization feature cache", %{org_id: org_id} do
    assert feature_state(org_id, "deployment_targets") == :enabled

    Support.Stubs.Feature.disable_feature(org_id, :deployment_targets)
    assert feature_state(org_id, "deployment_targets") == :enabled

    callback_message =
      %OrganizationFeaturesChanged{org_id: org_id} |> OrganizationFeaturesChanged.encode()

    assert :ok = Worker.organization_features_changed(callback_message)
    assert feature_state(org_id, "deployment_targets") == :disabled
  end

  defp feature_state(nil, feature_type) do
    {:ok, features} = FeatureProvider.list_features()
    features |> Enum.find(&(&1.type == feature_type)) |> Map.fetch!(:state)
  end

  defp feature_state(org_id, feature_type) do
    {:ok, features} = FeatureProvider.list_features(param: org_id)
    features |> Enum.find(&(&1.type == feature_type)) |> Map.fetch!(:state)
  end
end
