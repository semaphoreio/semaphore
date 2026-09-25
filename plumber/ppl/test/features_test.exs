defmodule Ppl.FeaturesTest do
  use ExUnit.Case, async: false

  @url_env_var "INTERNAL_API_URL_FEATURE"

  setup do
    # The result is memoized in :feature_cache; clear it so each test starts
    # fresh (e.g. the "unreachable" case must not see a cached value from the
    # "enabled" case for the same org id).
    Cachex.clear(:feature_cache)

    original = System.get_env(@url_env_var)
    System.put_env(@url_env_var, "localhost:50053")

    on_exit(fn ->
      case original do
        nil -> System.delete_env(@url_env_var)
        value -> System.put_env(@url_env_var, value)
      end
    end)

    :ok
  end

  describe "sparse_checkout_init_job_enabled?/1" do
    test "true when the feature is enabled for the org (via the FeatureHub mock)" do
      assert Ppl.Features.sparse_checkout_init_job_enabled?("org-123") == true
    end

    test "fails closed for a missing org id" do
      assert Ppl.Features.sparse_checkout_init_job_enabled?("") == false
      assert Ppl.Features.sparse_checkout_init_job_enabled?(nil) == false
    end

    test "fails closed when the Feature service is unreachable" do
      System.put_env(@url_env_var, "localhost:1")
      assert Ppl.Features.sparse_checkout_init_job_enabled?("org-123") == false
    end
  end

  describe "job_level_partial_rerun_enabled?/1" do
    test "true when the feature is enabled for the org (via the FeatureHub mock)" do
      assert Ppl.Features.job_level_partial_rerun_enabled?("org-123") == true
    end

    test "fails closed for a missing org id" do
      assert Ppl.Features.job_level_partial_rerun_enabled?("") == false
      assert Ppl.Features.job_level_partial_rerun_enabled?(nil) == false
    end

    test "fails closed when the Feature service is unreachable" do
      System.put_env(@url_env_var, "localhost:1")
      assert Ppl.Features.job_level_partial_rerun_enabled?("org-123") == false
    end
  end

  describe "with the YAML feature provider" do
    setup do
      name = "ppl_features_#{System.unique_integer([:positive])}.yml"
      path = Path.join(System.tmp_dir!(), name)

      File.write!(path, """
      job_level_partial_rerun:
        enabled: true
      sparse_checkout_init_job:
        enabled: false
      """)

      provider =
        {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :ppl_features_yaml_test]}

      start_supervised!(provider)

      original = Application.get_env(FeatureProvider, :provider)
      FeatureProvider.init(provider)

      on_exit(fn ->
        Application.put_env(FeatureProvider, :provider, original)
        File.rm(path)
      end)
    end

    test "reads enabled and disabled flags from the file" do
      assert Ppl.Features.job_level_partial_rerun_enabled?("org-yaml") == true
      assert Ppl.Features.sparse_checkout_init_job_enabled?("org-yaml") == false
    end

    test "does not depend on the Feature service" do
      System.put_env(@url_env_var, "localhost:1")
      assert Ppl.Features.job_level_partial_rerun_enabled?("org-yaml") == true
    end
  end

  describe "Ppl.Application.feature_provider_children/0" do
    setup do
      original = Application.get_env(:ppl, :feature_provider)
      on_exit(fn -> Application.put_env(:ppl, :feature_provider, original) end)
    end

    test "supervises the YAML provider's agent" do
      provider =
        {FeatureProvider.YamlProvider, [yaml_path: "features.yml", agent_name: :any_agent]}

      Application.put_env(:ppl, :feature_provider, provider)
      assert Ppl.Application.feature_provider_children() == [provider]
    end

    test "starts nothing for the FeatureHub provider" do
      Application.put_env(:ppl, :feature_provider, {Ppl.FeatureHubProvider, []})
      assert Ppl.Application.feature_provider_children() == []
    end
  end
end
