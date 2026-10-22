defmodule RepositoryHub.FeatureHubProviderTest do
  use ExUnit.Case, async: false

  import Mock

  alias InternalApi.Feature.{
    Availability,
    Feature,
    ListOrganizationFeaturesResponse,
    OrganizationFeature
  }

  alias InternalApi.Feature.FeatureService.Stub
  alias RepositoryHub.FeatureHubProvider

  defp org_feature(name, state) do
    %OrganizationFeature{
      feature: %Feature{name: name, type: name, description: ""},
      availability: %Availability{state: state, quantity: 1}
    }
  end

  test "maps decoded enum states (atoms) to feature states" do
    response = %ListOrganizationFeaturesResponse{
      organization_features: [
        org_feature("github_checks_api", :ENABLED),
        org_feature("zero", :ZERO_STATE),
        org_feature("hidden", :HIDDEN)
      ]
    }

    with_mocks([
      {GRPC.Stub, [:passthrough],
       [connect: fn _endpoint -> {:ok, :channel} end, disconnect: fn channel -> {:ok, channel} end]},
      {Stub, [], [list_organization_features: fn _channel, _request, _opts -> {:ok, response} end]}
    ]) do
      assert {:ok, features} = FeatureHubProvider.provide_features(Ecto.UUID.generate())

      states = Map.new(features, &{&1.type, &1.state})
      assert states["github_checks_api"] == :enabled
      assert states["zero"] == :zero_state
      refute Map.has_key?(states, "hidden")
      assert_called_exactly(GRPC.Stub.disconnect(:channel), 1)
    end
  end
end
