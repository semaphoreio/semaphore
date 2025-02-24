defmodule FeatureProviderTest do
  use FeatureProvider.MockedProviderCase

  doctest FeatureProvider, import: true

  setup do
    # For doctests
    provider = MockedProvider
    FeatureFactory.stub_provider(MockedProvider)

    old_env = Application.get_env(FeatureProvider, :provider)

    Application.put_env(FeatureProvider, :provider, provider)

    on_exit(fn ->
      Application.put_env(FeatureProvider, :provider, old_env)
    end)

    :ok
  end
end
