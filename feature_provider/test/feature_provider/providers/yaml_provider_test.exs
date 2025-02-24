defmodule FeatureProvider.YamlProviderTest do
  use ExUnit.Case
  doctest FeatureProvider.YamlProvider
  alias FeatureProvider.{YamlProvider, Feature}

  setup do
    provider = {YamlProvider, yaml_path: "test/fixtures/valid.yml", agent_name: :test_yaml_provider}
    {:ok, _} = start_supervised(provider)

    [provider: provider]
  end

  describe "works" do
    test "works", %{provider: provider} do
      assert {:ok, _} = FeatureProvider.find_feature("basic_setup", provider: provider)
      assert {:error, {:not_found, _}} = FeatureProvider.find_machine("basic_setup", provider: provider)
    end
  end

  describe "start_link/1" do
    test "raises if yaml_path is not provided" do
      assert_raise ArgumentError, "yaml_path must be a non-empty string", fn ->
        YamlProvider.start_link(agent_name: :test_yaml_provider)
      end
    end

    test "raises if yaml_path cannot be loaded" do
      assert_raise YamlElixir.FileNotFoundError,
                   "Failed to open file \"foo/bar\": no such file or directory",
                   fn ->
                     YamlProvider.start_link(yaml_path: "foo/bar", agent_name: :test_yaml_provider)
                   end
    end

    test "raises if yaml_path is invalid yaml" do
      assert_raise YamlElixir.ParsingError, fn ->
        YamlProvider.start_link(yaml_path: "test/fixtures/broken.yml", agent_name: :test_yaml_provider)
      end
    end

    test "works if yaml file has invalid schema" do
      provider = {YamlProvider, yaml_path: "test/fixtures/invalid.yml", agent_name: :invalid_yaml_provider}
      start_supervised!(provider)
      assert {:ok, features} = FeatureProvider.list_features(provider: provider)

      assert features == [
               %Feature{description: "0", name: "0", quantity: 1, state: :enabled, type: "0"},
               %Feature{
                 description: "Array",
                 name: "Array",
                 quantity: 1,
                 state: :enabled,
                 type: "array"
               },
               %Feature{
                 description: "Basic setup",
                 name: "Basic setup",
                 quantity: 1,
                 state: :enabled,
                 type: "basic_setup"
               },
               %Feature{
                 description: "Some bool",
                 name: "Some bool",
                 quantity: 1,
                 state: :enabled,
                 type: "some_bool"
               }
             ]
    end
  end
end
