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

  describe "errors" do
    defp provide_with(connect, call) do
      with_mocks([
        {GRPC.Stub, [:passthrough], [connect: connect, disconnect: fn channel -> {:ok, channel} end]},
        {Stub, [], [list_organization_features: call, list_features: call]}
      ]) do
        {FeatureHubProvider.provide_features(Ecto.UUID.generate()), FeatureHubProvider.provide_features(nil)}
      end
    end

    defp connected(_endpoint), do: {:ok, :channel}

    test "UNAVAILABLE and DEADLINE_EXCEEDED are reported as unavailable" do
      for status <- [GRPC.Status.unavailable(), GRPC.Status.deadline_exceeded()] do
        error = GRPC.RPCError.exception(status, "down")

        assert {{:error, {:unavailable, ^error}}, {:error, {:unavailable, ^error}}} =
                 provide_with(&connected/1, fn _, _, _ -> {:error, error} end)
      end
    end

    test "a failed connection is reported as unavailable" do
      assert {{:error, {:unavailable, "refused"}}, {:error, {:unavailable, "refused"}}} =
               provide_with(fn _ -> {:error, "refused"} end, fn _, _, _ -> flunk("called without a channel") end)
    end

    test "other gRPC errors are returned as is" do
      error = GRPC.RPCError.exception(GRPC.Status.not_found(), "no org")

      assert {{:error, ^error}, {:error, ^error}} = provide_with(&connected/1, fn _, _, _ -> {:error, error} end)
    end
  end
end
