defmodule ParameterizedProviderTest do
  use ExUnit.Case
  doctest ParameterizedProvider
  alias ParameterizedProvider

  describe "ParameterizedProvider" do
    setup do
      [provider: ParameterizedProvider]
    end

    test "can retrieve `param` from the FeatureProvider", %{provider: provider} do
      assert {:error, {:not_found, _}} = FeatureProvider.find_feature("a-feature-type", param: "id-1", provider: provider)
      assert {:ok, feature} = FeatureProvider.find_feature("a-feature-type", param: "id-2", provider: provider)
      assert feature.name == "A feature."
    end
  end
end
