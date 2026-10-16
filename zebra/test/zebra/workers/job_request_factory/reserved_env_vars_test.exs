defmodule Zebra.Workers.JobRequestFactory.ReservedEnvVarsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Semaphore.Jobs.V1alpha.Job.Spec
  alias Zebra.Workers.JobRequestFactory.{JobRequest, ReservedEnvVars, Secrets}

  @job %Zebra.Models.Job{id: Ecto.UUID.generate(), organization_id: Ecto.UUID.generate()}

  @no_secrets %Secrets{job_secrets: [], image_pull_secrets: [], container_secrets: []}

  defp spec(containers \\ []) do
    Spec.new(agent: Spec.Agent.new(containers: containers))
  end

  defp env_vars(names), do: Enum.map(names, &JobRequest.env_var(&1, "value"))

  defp secret(name, env_var_names),
    do: %Secrets.Secret{name: name, env_vars: env_vars(env_var_names), files: []}

  defp validate(job_type, spec_env_var_names, opts \\ []) do
    secrets = Keyword.get(opts, :secrets, @no_secrets)
    spec = Keyword.get(opts, :spec, spec())

    capture_log(fn ->
      send(
        self(),
        {:result,
         ReservedEnvVars.validate(@job, job_type, spec, env_vars(spec_env_var_names), secrets)}
      )
    end)

    assert_received {:result, result}
    result
  end

  describe "reserved?/1" do
    test "matches zebra-owned, plumber-owned and artefact-id names" do
      assert ReservedEnvVars.reserved?("SEMAPHORE_GIT_BRANCH")
      assert ReservedEnvVars.reserved?("SEMAPHORE_WORKFLOW_TRIGGERED_BY_API")
      assert ReservedEnvVars.reserved?("SEMAPHORE_PIPELINE_3_ARTEFACT_ID")
      assert ReservedEnvVars.reserved?("SEMAPHORE")
    end

    test "does not match names users are documented to set" do
      refute ReservedEnvVars.reserved?("SEMAPHORE_CACHE_BACKEND")
      refute ReservedEnvVars.reserved?("SEMAPHORE_CACHE_URL")
      refute ReservedEnvVars.reserved?("SEMAPHORE_CACHE_USERNAME")
      refute ReservedEnvVars.reserved?("SEMAPHORE_CACHE_PRIVATE_KEY_PATH")
      refute ReservedEnvVars.reserved?("SEMAPHORE_GIT_CLONE_SLOW_RETRY")
      refute ReservedEnvVars.reserved?("SEMAPHORE_CACHE_ARCHIVE_METHOD")
      refute ReservedEnvVars.reserved?("SEMAPHORE_TOOLBOX_METRICS_ENABLED")
      refute ReservedEnvVars.reserved?("SEMAPHORE_TEST_RESULTS_NO_TRIM")
      refute ReservedEnvVars.reserved?("SEMAPHORE_GIT_DEPTH")
      refute ReservedEnvVars.reserved?("SEMAPHORE_JOB_RESULT")
      refute ReservedEnvVars.reserved?("SEMAPHORE_PIPELINE_X_ARTEFACT_ID")
      refute ReservedEnvVars.reserved?("IGOR")
    end
  end

  @plumber_base_names [
    "SEMAPHORE_WORKFLOW_ID",
    "SEMAPHORE_WORKFLOW_NUMBER",
    "SEMAPHORE_WORKFLOW_RERUN",
    "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
    "SEMAPHORE_WORKFLOW_HOOK_SOURCE",
    "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE",
    "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API",
    "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
    "SEMAPHORE_PIPELINE_ARTEFACT_ID",
    "SEMAPHORE_PIPELINE_ID",
    "SEMAPHORE_PIPELINE_NAME",
    "SEMAPHORE_BLOCK_NAME",
    "SEMAPHORE_PIPELINE_RERUN",
    "SEMAPHORE_PIPELINE_PROMOTION",
    "SEMAPHORE_PIPELINE_PROMOTED_BY",
    "SEMAPHORE_WORKFLOW_TRIGGERED_BY",
    "SEMAPHORE_GIT_COMMIT_AUTHOR",
    "SEMAPHORE_GIT_COMMITTER",
    "SEMAPHORE_ORGANIZATION_ID",
    "SEMAPHORE_SNAPSHOT_ID",
    "SEMAPHORE_PIPELINE_0_ARTEFACT_ID",
    "SEMAPHORE_PIPELINE_1_ARTEFACT_ID",
    "SEMAPHORE_PIPELINE_2_ARTEFACT_ID"
  ]

  describe "validate/5 with the env vars Plumber sends" do
    test "accepts a parallel, rerun job of a promoted pipeline" do
      names =
        @plumber_base_names ++
          ["DEPLOY_TARGET", "GLOBAL_VAR", "BLOCK_VAR", "JOB_VAR"] ++
          ["SEMAPHORE_JOB_COUNT", "SEMAPHORE_JOB_INDEX"] ++
          ["SEMAPHORE_JOB_RERUN", "SEMAPHORE_JOB_ORIGINAL_ID"]

      assert validate(:pipeline_job, names) == :ok
      assert validate(:debug_job, names) == :ok
    end

    test "accepts an after_pipeline job" do
      names =
        @plumber_base_names ++
          [
            "SEMAPHORE_PIPELINE_TOTAL_DURATION",
            "SEMAPHORE_PIPELINE_INIT_DURATION",
            "SEMAPHORE_PIPELINE_QUEUEING_DURATION",
            "SEMAPHORE_PIPELINE_RUNNING_DURATION",
            "SEMAPHORE_PIPELINE_CREATED_AT",
            "SEMAPHORE_PIPELINE_STARTED_AT",
            "SEMAPHORE_PIPELINE_DONE_AT",
            "SEMAPHORE_PIPELINE_RESULT",
            "SEMAPHORE_PIPELINE_RESULT_REASON"
          ]

      assert validate(:pipeline_job, names) == :ok
    end

    test "accepts a pipeline initialization job" do
      assert validate(:pipeline_job, @plumber_base_names ++ ["SEMAPHORE_YAML_FILE_PATH"]) == :ok
    end

    test "rejects a promotion parameter that repeats a platform name" do
      names = @plumber_base_names ++ ["SEMAPHORE_WORKFLOW_TRIGGERED_BY"]

      assert validate(:pipeline_job, names) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY (job env_vars)"}
    end
  end

  describe "validate/5 name casing" do
    test "rejects a differently-cased repeat of a plumber-owned name" do
      names = ["SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "semaphore_workflow_triggered_by_api"]

      assert validate(:pipeline_job, names) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY_API (job env_vars)"}
    end

    test "rejects a lowercase zebra-owned name" do
      assert validate(:pipeline_job, ["semaphore_git_branch"]) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: semaphore_git_branch (job env_vars)"}
    end

    test "rejects mixed-case reserved names in secrets and artefact ids" do
      assert ReservedEnvVars.reserved?("Semaphore_Oidc_Token")
      assert ReservedEnvVars.reserved?("semaphore_pipeline_4_artefact_id")
      refute ReservedEnvVars.reserved?("semaphore_cache_backend")
    end
  end

  describe "valid_name?/1" do
    test "accepts shell identifiers" do
      assert ReservedEnvVars.valid_name?("MY_VAR")
      assert ReservedEnvVars.valid_name?("_private1")
      assert ReservedEnvVars.valid_name?("a")
    end

    test "rejects names the agent would not export as a single identifier" do
      refute ReservedEnvVars.valid_name?("")
      refute ReservedEnvVars.valid_name?("1VAR")
      refute ReservedEnvVars.valid_name?("MY-VAR")
      refute ReservedEnvVars.valid_name?("SEMAPHORE_WORKFLOW_TRIGGERED_BY_API=true #")
      refute ReservedEnvVars.valid_name?("X=1; id; Y")
      refute ReservedEnvVars.valid_name?("A\nB")
      refute ReservedEnvVars.valid_name?("FOO\n")
      refute ReservedEnvVars.valid_name?("\nFOO")
      refute ReservedEnvVars.valid_name?("A B")
      refute ReservedEnvVars.valid_name?("ÜBER")
      refute ReservedEnvVars.valid_name?(nil)
    end
  end

  describe "validate/5 with invalid names" do
    test "rejects a name that would inject shell code" do
      assert validate(:pipeline_job, ["X=1; id; Y"]) ==
               {:stop_job_processing,
                "Invalid environment variable names: 'X=1; id; Y' (job env_vars)"}
    end

    test "rejects an assignment hidden in a name, before checking reserved names" do
      names = ["SEMAPHORE_GIT_BRANCH", "SEMAPHORE_JOB_ID=1 #"]

      assert validate(:pipeline_job, names) ==
               {:stop_job_processing,
                "Invalid environment variable names: 'SEMAPHORE_JOB_ID=1 #' (job env_vars)"}
    end

    test "rejects an empty name" do
      assert validate(:project_debug_job, [""]) ==
               {:stop_job_processing, "Invalid environment variable names: '' (job env_vars)"}
    end

    test "rejects a reserved name followed by a trailing newline" do
      assert validate(:pipeline_job, ["SEMAPHORE_WORKFLOW_TRIGGERED_BY_API\n"]) ==
               {:stop_job_processing,
                "Invalid environment variable names: 'SEMAPHORE_WORKFLOW_TRIGGERED_BY_API?' (job env_vars)"}
    end

    test "shows control characters as ? in the reason" do
      assert validate(:pipeline_job, ["A\nB"]) ==
               {:stop_job_processing, "Invalid environment variable names: 'A?B' (job env_vars)"}
    end

    test "rejects invalid names in containers before looking at secrets" do
      secrets = %{@no_secrets | job_secrets: [secret("deploy", ["BAD NAME"])]}

      container =
        Spec.Agent.Container.new(
          name: "main",
          env_vars: [Spec.EnvVar.new(name: "1ST", value: "x")]
        )

      assert validate(:pipeline_job, [], secrets: secrets, spec: spec([container])) ==
               {:stop_job_processing,
                "Invalid environment variable names: '1ST' (container 'main' env_vars)"}
    end

    test "rejects invalid names in secrets" do
      secrets = %{
        @no_secrets
        | job_secrets: [secret("deploy", ["OK", "BAD NAME"])],
          container_secrets: [[secret("db", ["db-pass"])]],
          image_pull_secrets: [secret("registry", ["X;Y"])]
      }

      assert validate(:pipeline_job, [], secrets: secrets) ==
               {:stop_job_processing,
                "Invalid environment variable names: 'BAD NAME' (secret 'deploy'), " <>
                  "'db-pass' (secret 'db'), 'X;Y' (image pull secret 'registry')"}
    end

    test "logs escaped names" do
      log =
        capture_log(fn ->
          ReservedEnvVars.validate(
            @job,
            :pipeline_job,
            spec(),
            [JobRequest.env_var("A\nB", "very-secret-value")],
            @no_secrets
          )
        end)

      assert log =~ ~s(Invalid env var names rejected job_id=#{@job.id})
      assert log =~ ~s(names=["A?B"])
      refute log =~ "A\nB"
      refute log =~ "very-secret-value"
    end
  end

  describe "validate/5 known limitation" do
    test "accepts a single copy of a conditional plumber-owned name in a pipeline job" do
      # Zebra cannot tell this copy apart from one Plumber added for a parallel or rerun job.
      assert validate(:pipeline_job, @plumber_base_names ++ ["SEMAPHORE_JOB_COUNT"]) == :ok
    end
  end

  describe "validate/5 for pipeline jobs" do
    test "accepts plumber-owned names present once" do
      names = [
        "SEMAPHORE_WORKFLOW_ID",
        "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API",
        "SEMAPHORE_PIPELINE_0_ARTEFACT_ID",
        "SEMAPHORE_PIPELINE_1_ARTEFACT_ID",
        "SEMAPHORE_CACHE_BACKEND",
        "IGOR"
      ]

      assert validate(:pipeline_job, names) == :ok
      assert validate(:debug_job, names) == :ok
    end

    test "rejects a plumber-owned name present more than once" do
      names = [
        "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API",
        "IGOR",
        "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API"
      ]

      assert validate(:pipeline_job, names) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY_API (job env_vars)"}
    end

    test "rejects a duplicated artefact-id name" do
      names = ["SEMAPHORE_PIPELINE_2_ARTEFACT_ID", "SEMAPHORE_PIPELINE_2_ARTEFACT_ID"]

      assert {:stop_job_processing, _} = validate(:debug_job, names)
    end

    test "rejects a zebra-owned name present once" do
      assert validate(:pipeline_job, ["SEMAPHORE_GIT_BRANCH"]) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_GIT_BRANCH (job env_vars)"}
    end
  end

  describe "validate/5 for jobs outside a pipeline" do
    test "rejects any reserved name" do
      assert validate(:project_debug_job, ["SEMAPHORE_WORKFLOW_TRIGGERED_BY_API"]) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY_API (job env_vars)"}
    end

    test "accepts non-reserved names" do
      assert validate(:project_debug_job, ["IGOR", "SEMAPHORE_GIT_DEPTH"]) == :ok
    end
  end

  describe "validate/5 for secrets and containers" do
    test "rejects a reserved name in a job secret" do
      secrets = %{@no_secrets | job_secrets: [secret("deploy", ["A", "SEMAPHORE_GIT_SHA"])]}

      assert validate(:pipeline_job, [], secrets: secrets) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_GIT_SHA (secret 'deploy')"}
    end

    test "rejects a plumber-owned name in a secret even when the spec has none" do
      secrets = %{
        @no_secrets
        | job_secrets: [secret("deploy", ["SEMAPHORE_PIPELINE_PROMOTED_BY"])]
      }

      assert {:stop_job_processing, _} = validate(:pipeline_job, [], secrets: secrets)
    end

    test "rejects a reserved name in a container secret" do
      secrets = %{@no_secrets | container_secrets: [[], [secret("db", ["SEMAPHORE_JOB_ID"])]]}

      assert validate(:pipeline_job, [], secrets: secrets) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_JOB_ID (secret 'db')"}
    end

    test "rejects a reserved name in an image pull secret" do
      secrets = %{
        @no_secrets
        | image_pull_secrets: [secret("registry", ["SEMAPHORE_OIDC_TOKEN"])]
      }

      assert validate(:pipeline_job, [], secrets: secrets) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_OIDC_TOKEN (image pull secret 'registry')"}
    end

    test "rejects a reserved name in container env_vars" do
      container =
        Spec.Agent.Container.new(
          name: "main",
          env_vars: [Spec.EnvVar.new(name: "SEMAPHORE_WORKFLOW_TRIGGERED_BY", value: "nobody")]
        )

      assert validate(:pipeline_job, [], spec: spec([container])) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_WORKFLOW_TRIGGERED_BY (container 'main' env_vars)"}
    end

    test "accepts secrets and containers without reserved names" do
      secrets = %{@no_secrets | job_secrets: [secret("deploy", ["A", "SEMAPHORE_CACHE_URL"])]}

      container =
        Spec.Agent.Container.new(name: "db", env_vars: [Spec.EnvVar.new(name: "PG", value: "1")])

      assert validate(:pipeline_job, [], secrets: secrets, spec: spec([container])) == :ok
    end
  end

  describe "validate_spec/4 and validate_secrets/2" do
    test "validate_spec/4 rejects spec and container names" do
      container =
        Spec.Agent.Container.new(
          name: "db",
          env_vars: [Spec.EnvVar.new(name: "SEMAPHORE_JOB_ID", value: "x")]
        )

      assert ReservedEnvVars.validate_spec(
               @job,
               :pipeline_job,
               spec([container]),
               env_vars(["SEMAPHORE_GIT_BRANCH"])
             ) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_GIT_BRANCH (job env_vars), " <>
                  "SEMAPHORE_JOB_ID (container 'db' env_vars)"}
    end

    test "validate_spec/4 accepts a clean spec" do
      assert ReservedEnvVars.validate_spec(@job, :pipeline_job, spec(), env_vars(["IGOR"])) == :ok
    end

    test "validate_secrets/2 rejects reserved and invalid names in secrets" do
      reserved = %{@no_secrets | job_secrets: [secret("deploy", ["SEMAPHORE_GIT_SHA"])]}
      invalid = %{@no_secrets | image_pull_secrets: [secret("registry", ["X;Y"])]}

      assert ReservedEnvVars.validate_secrets(@job, reserved) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_GIT_SHA (secret 'deploy')"}

      assert ReservedEnvVars.validate_secrets(@job, invalid) ==
               {:stop_job_processing,
                "Invalid environment variable names: 'X;Y' (image pull secret 'registry')"}
    end

    test "validate_secrets/2 accepts clean secrets" do
      secrets = %{@no_secrets | job_secrets: [secret("deploy", ["A", "SEMAPHORE_CACHE_URL"])]}

      assert ReservedEnvVars.validate_secrets(@job, secrets) == :ok
    end

    test "validate/5 reports spec violations without reading secrets" do
      secrets = %{@no_secrets | job_secrets: [secret("deploy", ["SEMAPHORE_GIT_SHA"])]}

      assert validate(:pipeline_job, ["SEMAPHORE_GIT_BRANCH"], secrets: secrets) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_GIT_BRANCH (job env_vars)"}
    end
  end

  describe "validate/5 rejection message" do
    test "lists each violation once" do
      secrets = %{
        @no_secrets
        | job_secrets: [secret("deploy", ["SEMAPHORE_GIT_SHA", "SEMAPHORE_GIT_SHA"])]
      }

      assert validate(:pipeline_job, [], secrets: secrets) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_GIT_SHA (secret 'deploy')"}
    end

    test "fits in 255 characters when there are many violations" do
      names = [
        "SEMAPHORE_GIT_PROVIDER",
        "SEMAPHORE_GIT_URL",
        "SEMAPHORE_GIT_REPO_NAME",
        "SEMAPHORE_GIT_DIR",
        "SEMAPHORE_GIT_SHA",
        "SEMAPHORE_GIT_REPO_SLUG",
        "SEMAPHORE_GIT_REF",
        "SEMAPHORE_GIT_COMMIT_RANGE",
        "SEMAPHORE_GIT_BRANCH",
        "SEMAPHORE_GIT_WORKING_BRANCH"
      ]

      assert {:stop_job_processing, message} = validate(:pipeline_job, names)
      assert String.length(message) <= 255
      assert message =~ "SEMAPHORE_GIT_PROVIDER (job env_vars)"
      assert message =~ ~r/ and \d+ more$/
    end

    test "clips long secret names" do
      secrets = %{
        @no_secrets
        | job_secrets: [secret(String.duplicate("s", 300), ["SEMAPHORE_GIT_SHA"])]
      }

      assert validate(:pipeline_job, [], secrets: secrets) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_GIT_SHA (secret '#{String.duplicate("s", 40)}')"}
    end

    test "fits in 255 codepoints when names are made of multi-codepoint graphemes" do
      combining = "x" <> String.duplicate("\u0301", 300)
      zwj_family = String.duplicate("\u{1F468}\u200D\u{1F469}\u200D\u{1F467}", 60)

      container =
        Spec.Agent.Container.new(
          name: combining,
          env_vars: [Spec.EnvVar.new(name: "SEMAPHORE_JOB_ID", value: "x")]
        )

      secrets = %{
        @no_secrets
        | job_secrets: [secret(zwj_family, ["SEMAPHORE_GIT_SHA", "SEMAPHORE_GIT_BRANCH"])],
          image_pull_secrets: [secret(combining, ["SEMAPHORE_OIDC_TOKEN"])]
      }

      assert {:stop_job_processing, message} =
               validate(:pipeline_job, [], secrets: secrets, spec: spec([container]))

      assert String.valid?(message)
      assert message |> String.codepoints() |> length() <= 255
    end

    test "drops invalid UTF-8 from names in the message" do
      secrets = %{
        @no_secrets
        | job_secrets: [secret(<<"bad", 0xFF, 0xFE>>, ["SEMAPHORE_GIT_SHA"])]
      }

      assert validate(:pipeline_job, [], secrets: secrets) ==
               {:stop_job_processing,
                "Reserved environment variables cannot be set: SEMAPHORE_GIT_SHA (secret 'bad')"}
    end

    test "logs names only, never values" do
      log =
        capture_log(fn ->
          ReservedEnvVars.validate(
            @job,
            :pipeline_job,
            spec(),
            [JobRequest.env_var("SEMAPHORE_GIT_BRANCH", "very-secret-value")],
            @no_secrets
          )
        end)

      assert log =~ "names=SEMAPHORE_GIT_BRANCH"
      assert log =~ "job_id=#{@job.id}"
      refute log =~ "very-secret-value"
      refute log =~ Base.encode64("very-secret-value")
    end
  end
end
