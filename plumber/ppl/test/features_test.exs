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
end
