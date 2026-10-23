defmodule EnvVarPolicyTest do
  use ExUnit.Case, async: true

  describe "reserved?/1" do
    test "matches names Zebra and Plumber inject, in any case" do
      for name <- [
            "SEMAPHORE",
            "SEMAPHORE_GIT_BRANCH",
            "SEMAPHORE_OIDC_TOKEN",
            "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
            "SEMAPHORE_JOB_COUNT",
            "SEMAPHORE_PIPELINE_7_ARTEFACT_ID",
            "semaphore_workflow_triggered_by_api"
          ] do
        assert EnvVarPolicy.reserved?(name), "expected #{name} to be reserved"
      end
    end

    test "does not match the settings users are documented to set" do
      for name <- [
            "SEMAPHORE_CACHE_BACKEND",
            "SEMAPHORE_CACHE_URL",
            "SEMAPHORE_CACHE_USERNAME",
            "SEMAPHORE_CACHE_PRIVATE_KEY_PATH",
            "SEMAPHORE_CACHE_ARCHIVE_METHOD",
            "SEMAPHORE_CACHE_S3_BUCKET",
            "SEMAPHORE_CACHE_GCS_BUCKET",
            "SEMAPHORE_GIT_DEPTH",
            "SEMAPHORE_GIT_CACHE_AGE",
            "SEMAPHORE_GIT_CACHE_KEEP",
            "SEMAPHORE_GIT_CLONE_SLOW_RETRY",
            "SEMAPHORE_TEST_RESULTS_NO_TRIM",
            "SEMAPHORE_TOOLBOX_METRICS_ENABLED",
            "SEMAPHORE_AGENT_UPLOAD_JOB_LOGS",
            "SEMAPHORE_JOB_RESULT",
            "SEMAPHORE_PIPELINE_X_ARTEFACT_ID",
            "MY_VAR"
          ] do
        refute EnvVarPolicy.reserved?(name), "expected #{name} to be allowed"
      end
    end

    test "is false for non-binary names" do
      refute EnvVarPolicy.reserved?(nil)
      refute EnvVarPolicy.reserved?(1)
    end
  end

  describe "zebra_owned?/1 and plumber_owned?/1" do
    test "split the reserved names by the service that injects them" do
      assert EnvVarPolicy.zebra_owned?("SEMAPHORE_GIT_SHA")
      refute EnvVarPolicy.plumber_owned?("SEMAPHORE_GIT_SHA")

      assert EnvVarPolicy.plumber_owned?("SEMAPHORE_WORKFLOW_ID")
      refute EnvVarPolicy.zebra_owned?("SEMAPHORE_WORKFLOW_ID")

      assert EnvVarPolicy.plumber_owned?("SEMAPHORE_PIPELINE_0_ARTEFACT_ID")
    end
  end

  describe "valid_name?/1" do
    test "accepts shell identifiers" do
      for name <- ["MY_VAR", "_private1", "a"] do
        assert EnvVarPolicy.valid_name?(name), "expected #{name} to be valid"
      end
    end

    test "rejects anything the agent would not export as a single identifier" do
      for name <- [
            "",
            "1VAR",
            "MY-VAR",
            "discovery.type",
            "A B",
            "X=1; id; Y",
            "FOO\n",
            "\nFOO",
            "ÉCOLE",
            nil
          ] do
        refute EnvVarPolicy.valid_name?(name), "expected #{inspect(name)} to be invalid"
      end
    end
  end

  describe "valid_container_name?/1" do
    test "also accepts dotted and dashed names" do
      for name <- ["discovery.type", "xpack.security.enabled", "node-version", "MY_VAR"] do
        assert EnvVarPolicy.valid_container_name?(name), "expected #{name} to be valid"
      end
    end

    test "rejects names that would break the docker-compose environment line" do
      for name <- ["", "1ST", ".hidden", "A B", "A=B", "A:B", "A#B", "A\nB", "FOO\n", nil] do
        refute EnvVarPolicy.valid_container_name?(name),
               "expected #{inspect(name)} to be invalid"
      end
    end
  end

  describe "clip/1" do
    test "keeps reserved names whole" do
      assert EnvVarPolicy.clip("SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN") ==
               "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN"
    end

    test "keeps at most 64 codepoints" do
      assert EnvVarPolicy.clip(String.duplicate("a", 100)) == String.duplicate("a", 64)

      combining = "x" <> String.duplicate("́", 300)
      assert combining |> EnvVarPolicy.clip() |> String.codepoints() |> length() == 64
    end

    test "drops invalid UTF-8 and replaces control characters" do
      assert EnvVarPolicy.clip(<<"bad", 0xFF, "name">>) == "badname"
      assert EnvVarPolicy.clip("a\nb\tc") == "a?b?c"
    end
  end
end
