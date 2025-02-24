defmodule ProvidersTest do
  use FeatureProvider.MockedProviderCase

  describe "using MockedProvider" do
    setup do
      [provider: MockedProvider]
    end

    test "mocks calls to the provider", %{provider: provider} do
      MockedProvider
      |> expect(:provide_features, fn _args, _opts -> {:ok, []} end)
      |> expect(:provide_features, fn _args, _opts -> {:ok, FeatureFactory.build_features(["a-feature-type"])} end)

      assert {:error, {:not_found, _}} = FeatureProvider.find_feature("a-feature-type", provider: provider)
      assert {:ok, _} = FeatureProvider.find_feature("a-feature-type", provider: provider)
    end
  end

  describe "using YamlProvider" do
    setup do
      provider = {FeatureProvider.YamlProvider, yaml_path: "test/fixtures/valid.yml", agent_name: :yaml_provider}
      start_supervised!(provider)

      [provider: provider]
    end

    test "passes options provided to the provider down to the funs", %{provider: provider} do
      assert {:error, {:not_found, _}} = FeatureProvider.find_feature("non-existing-feature", provider: provider)
      assert {:ok, _} = FeatureProvider.find_feature("basic_setup", provider: provider)
    end
  end

  describe "using cache" do
    setup do
      {:ok, _} = start_supervised({Cachex, name: :mocked_provider_cache})
      provider = {MockedProvider, [cache: {FeatureProvider.CachexCache, name: :mocked_provider_cache}]}

      [provider: provider]
    end

    test "works by setting `:cache` key with a proper cache", %{provider: provider} do
      MockedProvider
      |> expect(:provide_features, fn _args, _opts -> {:ok, []} end)
      |> expect(:provide_features, fn _args, _opts -> {:ok, FeatureFactory.build_features(["a-feature-type"])} end)

      assert {:error, {:not_found, _}} = FeatureProvider.find_feature("non-existing-feature", provider: provider)
      assert {:error, {:not_found, _}} = FeatureProvider.find_feature("a-feature-type", provider: provider)
      assert {:ok, _} = FeatureProvider.find_feature("a-feature-type", reload: true, provider: provider)
      assert {:ok, _} = FeatureProvider.find_feature("a-feature-type", provider: provider)
    end
  end
end
