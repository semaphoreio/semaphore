defmodule Projecthub.FeatureProviderInvalidatorWorkerTest do
  use Projecthub.DataCase

  alias InternalApi.Feature.{Availability, ListOrganizationFeaturesResponse, OrganizationFeaturesChanged}
  alias Projecthub.FeatureProviderInvalidatorWorker

  test "an organization feature change applies right after the change event" do
    org_id = Ecto.UUID.generate()

    stub_just_run(:HIDDEN)
    refute FeatureProvider.feature_enabled?(:just_run, param: org_id)

    stub_just_run(:ENABLED)
    refute FeatureProvider.feature_enabled?(:just_run, param: org_id)

    OrganizationFeaturesChanged.new(org_id: org_id)
    |> OrganizationFeaturesChanged.encode()
    |> FeatureProviderInvalidatorWorker.organization_features_changed()

    assert FeatureProvider.feature_enabled?(:just_run, param: org_id)
  end

  defp stub_just_run(state) do
    FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
      ListOrganizationFeaturesResponse.new(
        organization_features: [
          [feature: %{type: "just_run"}, availability: Availability.new(state: state, quantity: 1)]
        ]
      )
    end)
  end
end
