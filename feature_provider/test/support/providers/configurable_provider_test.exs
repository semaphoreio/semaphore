defmodule ConfigurableProviderTest do
  use ExUnit.Case
  doctest ConfigurableProvider
  alias ConfigurableProvider

  describe "ConfigurableProvider" do
    setup do
      features = FeatureFactory.build_features(["a-feature-type"])
      provider = {ConfigurableProvider, [features: features]}

      [provider: provider]
    end

    test "passes options provided to the provider down to the funs", %{provider: provider} do
      assert {:error, {:not_found, _}} = FeatureProvider.find_feature("non-existing-feature", provider: provider)
      assert {:ok, _} = FeatureProvider.find_feature("a-feature-type", provider: provider)
    end
  end
end
