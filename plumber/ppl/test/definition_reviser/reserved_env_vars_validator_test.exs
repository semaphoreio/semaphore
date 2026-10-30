defmodule Ppl.DefinitionReviser.ReservedEnvVarsValidator.Test do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Ppl.DefinitionReviser
  alias Ppl.DefinitionReviser.ReservedEnvVarsValidator

  @ppl_req %{request_args: %{}}

  defp env_var(name), do: %{"name" => name, "value" => "x"}

  defp definition(opts \\ []) do
    job =
      %{"name" => "Test", "commands" => ["echo"]}
      |> maybe_put("env_vars", opts[:job_env_vars])
      |> maybe_put("matrix", opts[:matrix])

    build =
      %{"jobs" => [job]}
      |> maybe_put("env_vars", opts[:block_env_vars])
      |> maybe_put("agent", opts[:block_agent])

    %{
      "version" => "v1.0",
      "agent" => %{"machine" => %{"type" => "e1-standard-2"}},
      "blocks" => [%{"name" => "Build", "build" => build}]
    }
    |> maybe_put("global_job_config", opts[:global_job_config])
    |> maybe_put("promotions", opts[:promotions])
    |> maybe_put("after_pipeline", opts[:after_pipeline])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp reserved(entries),
    do: {:error, {:malformed, "Reserved environment variables cannot be set: " <> entries}}

  defp invalid(entries),
    do: {:error, {:malformed, "Invalid environment variable names: " <> entries}}

  describe "reserved?/1" do
    test "matches reserved names in any case and the artefact-id pattern" do
      assert ReservedEnvVarsValidator.reserved?("SEMAPHORE_JOB_COUNT")
      assert ReservedEnvVarsValidator.reserved?("semaphore_workflow_triggered_by_api")
      assert ReservedEnvVarsValidator.reserved?("SEMAPHORE_PIPELINE_7_ARTEFACT_ID")
      assert ReservedEnvVarsValidator.reserved?("SEMAPHORE")
    end

    test "does not match the settings users are documented to set" do
      for name <- [
            "SEMAPHORE_CACHE_BACKEND",
            "SEMAPHORE_CACHE_URL",
            "SEMAPHORE_CACHE_USERNAME",
            "SEMAPHORE_CACHE_PRIVATE_KEY_PATH",
            "SEMAPHORE_CACHE_ARCHIVE_METHOD",
            "SEMAPHORE_GIT_DEPTH",
            "SEMAPHORE_GIT_DIR",
            "SEMAPHORE_GIT_CLONE_SLOW_RETRY",
            "SEMAPHORE_TEST_RESULTS_NO_TRIM",
            "SEMAPHORE_TOOLBOX_METRICS_ENABLED",
            "SEMAPHORE_AGENT_UPLOAD_JOB_LOGS",
            "SEMAPHORE_JOB_RESULT",
            "SEMAPHORE_PIPELINE_X_ARTEFACT_ID",
            "MY_VAR"
          ] do
        refute ReservedEnvVarsValidator.reserved?(name), "expected #{name} to be allowed"
      end

      refute ReservedEnvVarsValidator.reserved?(nil)
    end
  end

  describe "valid_container_name?/1" do
    test "accepts the dotted and dashed names service containers use" do
      for name <- ["discovery.type", "xpack.security.enabled", "node-version", "MY_VAR"] do
        assert ReservedEnvVarsValidator.valid_container_name?(name),
               "expected #{name} to be valid"
      end
    end

    test "rejects names that would break the docker-compose environment line" do
      for name <- ["", "1ST", ".hidden", "A B", "A=B", "A:B", "A#B", "A\nB", "FOO\n", nil] do
        refute ReservedEnvVarsValidator.valid_container_name?(name),
               "expected #{inspect(name)} to be invalid"
      end
    end
  end

  describe "valid_name?/1" do
    test "accepts shell identifiers" do
      assert ReservedEnvVarsValidator.valid_name?("MY_VAR")
      assert ReservedEnvVarsValidator.valid_name?("_private1")
    end

    test "rejects names the agent would not export as a single identifier" do
      for name <- ["", "1VAR", "MY-VAR", "A B", "X=1; id; Y", "FOO\n", "\nFOO", "ÉCOLE", nil] do
        refute ReservedEnvVarsValidator.valid_name?(name),
               "expected #{inspect(name)} to be invalid"
      end
    end
  end

  describe "validate/2" do
    test "accepts a definition without reserved or invalid names" do
      definition =
        definition(
          job_env_vars: [env_var("MY_VAR"), env_var("SEMAPHORE_GIT_DEPTH")],
          block_env_vars: [env_var("SEMAPHORE_CACHE_BACKEND")],
          global_job_config: %{"env_vars" => [env_var("GLOBAL")]},
          matrix: [%{"env_var" => "RUBY", "values" => ["3.2"]}]
        )

      ppl_req = %{request_args: %{"env_vars" => [env_var("DEPLOY_ENV")]}}

      assert ReservedEnvVarsValidator.validate(definition, ppl_req) == {:ok, definition}
    end

    test "accepts requests without parameters" do
      definition = definition()

      assert ReservedEnvVarsValidator.validate(definition, %{request_args: nil}) ==
               {:ok, definition}

      assert ReservedEnvVarsValidator.validate(definition, %{}) == {:ok, definition}
    end

    test "rejects a variable Plumber only adds to some jobs, even where it would not" do
      definition = definition(job_env_vars: [env_var("SEMAPHORE_JOB_COUNT")])

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) ==
               reserved("SEMAPHORE_JOB_COUNT (block 'Build', job 'Test')")
    end

    test "rejects reserved names in every location" do
      definition =
        definition(
          global_job_config: %{"env_vars" => [env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY")]},
          block_env_vars: [env_var("SEMAPHORE_GIT_BRANCH")],
          job_env_vars: [env_var("SEMAPHORE_JOB_RERUN")],
          matrix: [%{"env_var" => "SEMAPHORE_JOB_INDEX", "values" => ["1"]}],
          block_agent: %{
            "containers" => [%{"name" => "db", "env_vars" => [env_var("SEMAPHORE_JOB_ID")]}]
          },
          promotions: [
            %{
              "name" => "Deploy",
              "pipeline_file" => "deploy.yml",
              "parameters" => %{"env_vars" => [%{"name" => "SEMAPHORE_GIT_SHA"}]}
            }
          ],
          after_pipeline: [
            %{
              "build" => %{
                "jobs" => [
                  %{"name" => "Notify", "env_vars" => [env_var("SEMAPHORE_PIPELINE_RESULT")]}
                ]
              }
            }
          ]
        )
        |> put_in(["agent", "containers"], [
          %{"name" => "main", "env_vars" => [env_var("SEMAPHORE_SNAPSHOT_ID")]}
        ])

      ppl_req = %{request_args: %{"env_vars" => [env_var("SEMAPHORE_PIPELINE_PROMOTED_BY")]}}

      assert ReservedEnvVarsValidator.validate(definition, ppl_req) ==
               reserved(
                 "SEMAPHORE_WORKFLOW_TRIGGERED_BY (global_job_config), " <>
                   "SEMAPHORE_SNAPSHOT_ID (agent container 'main'), " <>
                   "SEMAPHORE_GIT_SHA (promotion 'Deploy' parameters), " <>
                   "SEMAPHORE_GIT_BRANCH (block 'Build'), " <>
                   "SEMAPHORE_JOB_ID (block 'Build' container 'db'), " <>
                   "SEMAPHORE_JOB_RERUN (block 'Build', job 'Test'), " <>
                   "SEMAPHORE_JOB_INDEX (block 'Build', job 'Test' matrix), " <>
                   "SEMAPHORE_PIPELINE_RESULT (block 'after_pipeline', job 'Notify'), " <>
                   "SEMAPHORE_PIPELINE_PROMOTED_BY (parameters)"
               )
    end

    test "rejects differently-cased reserved names and artefact ids" do
      definition =
        definition(
          job_env_vars: [
            env_var("semaphore_workflow_triggered_by_api"),
            env_var("SEMAPHORE_PIPELINE_9_ARTEFACT_ID")
          ]
        )

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) ==
               reserved(
                 "semaphore_workflow_triggered_by_api (block 'Build', job 'Test'), " <>
                   "SEMAPHORE_PIPELINE_9_ARTEFACT_ID (block 'Build', job 'Test')"
               )
    end

    test "lists each violation once" do
      definition =
        definition(job_env_vars: [env_var("SEMAPHORE_JOB_COUNT"), env_var("SEMAPHORE_JOB_COUNT")])

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) ==
               reserved("SEMAPHORE_JOB_COUNT (block 'Build', job 'Test')")
    end

    test "rejects invalid names before checking reserved names" do
      definition =
        definition(
          job_env_vars: [env_var("SEMAPHORE_GIT_BRANCH"), env_var("SEMAPHORE_JOB_ID=1 #")],
          block_env_vars: [env_var("MY-VAR")],
          matrix: [%{"env_var" => "1ST", "values" => ["a"]}]
        )

      ppl_req = %{request_args: %{"env_vars" => [env_var("X=1; id; Y")]}}

      assert ReservedEnvVarsValidator.validate(definition, ppl_req) ==
               invalid(
                 "'MY-VAR' (block 'Build'), " <>
                   "'SEMAPHORE_JOB_ID=1 #' (block 'Build', job 'Test'), " <>
                   "'1ST' (block 'Build', job 'Test' matrix), " <>
                   "'X=1; id; Y' (parameters)"
               )
    end

    test "rejects empty names and names with a trailing newline" do
      definition = definition(job_env_vars: [env_var(""), env_var("SEMAPHORE_GIT_SHA\n")])

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) ==
               invalid(
                 "'' (block 'Build', job 'Test'), 'SEMAPHORE_GIT_SHA?' (block 'Build', job 'Test')"
               )
    end

    test "accepts dotted names in pipeline and block service container env_vars" do
      container = %{
        "name" => "es",
        "env_vars" => [env_var("discovery.type"), env_var("xpack.security.enabled")]
      }

      definition =
        definition(block_agent: %{"containers" => [container]})
        |> put_in(["agent", "containers"], [container])

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) == {:ok, definition}
    end

    test "still rejects dotted names outside containers" do
      definition = definition(job_env_vars: [env_var("discovery.type")])

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) ==
               invalid("'discovery.type' (block 'Build', job 'Test')")
    end

    test "rejects container env var names that would break the compose file" do
      definition =
        put_in(definition(), ["agent", "containers"], [
          %{"name" => "es", "env_vars" => [env_var("a=b")]}
        ])

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) ==
               invalid("'a=b' (agent container 'es')")
    end

    test "shows long reserved names in full" do
      definition =
        definition(job_env_vars: [env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN")])

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) ==
               reserved("SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN (block 'Build', job 'Test')")
    end

    test "clips long names and replaces control characters in the message" do
      long = String.duplicate("a", 100) <> "-"
      definition = definition(job_env_vars: [env_var(long), env_var("A\tB")])

      assert ReservedEnvVarsValidator.validate(definition, @ppl_req) ==
               invalid(
                 "'#{String.duplicate("a", 64)}' (block 'Build', job 'Test'), " <>
                   "'A?B' (block 'Build', job 'Test')"
               )
    end
  end

  describe "validate_parameters/1" do
    test "accepts requests without reserved or invalid parameter names" do
      assert ReservedEnvVarsValidator.validate_parameters(%{
               request_args: %{"env_vars" => [env_var("DEPLOY_ENV")]}
             }) == :ok

      assert ReservedEnvVarsValidator.validate_parameters(%{request_args: %{}}) == :ok
      assert ReservedEnvVarsValidator.validate_parameters(%{request_args: nil}) == :ok
    end

    test "rejects reserved and invalid parameter names" do
      assert ReservedEnvVarsValidator.validate_parameters(%{
               request_args: %{"env_vars" => [env_var("SEMAPHORE_PIPELINE_RESULT")]}
             }) == reserved("SEMAPHORE_PIPELINE_RESULT (parameters)")

      assert ReservedEnvVarsValidator.validate_parameters(%{
               request_args: %{"env_vars" => [env_var("deploy-env")]}
             }) == invalid("'deploy-env' (parameters)")
    end

    test "rejects bash startup variables" do
      assert ReservedEnvVarsValidator.validate_parameters(%{
               request_args: %{"env_vars" => [env_var("BASH_ENV"), env_var("SHELLOPTS")]}
             }) == reserved("BASH_ENV (parameters), SHELLOPTS (parameters)")
    end

    test "logs the rejected names with the pipeline and organization ids" do
      ppl_req = %{
        id: "ppl-1",
        request_args: %{"organization_id" => "org-1", "env_vars" => [env_var("SEMAPHORE_JOB_ID")]}
      }

      log = capture_log(fn -> ReservedEnvVarsValidator.validate_parameters(ppl_req) end)

      assert log =~
               ~s(Env vars rejected kind=reserved ppl_id=ppl-1 org_id=org-1 names=["SEMAPHORE_JOB_ID"])
    end

    test "logs invalid names escaped" do
      ppl_req = %{id: "ppl-1", request_args: %{"env_vars" => [env_var("A\nB")]}}

      log = capture_log(fn -> ReservedEnvVarsValidator.validate_parameters(ppl_req) end)

      assert log =~ ~s(kind=invalid ppl_id=ppl-1 org_id= names=["A?B"])
    end
  end

  describe "validate/2 message length" do
    test "lists at most 20 violations and counts the rest" do
      names = Enum.map(1..25, &"BAD-#{&1}")
      definition = definition(job_env_vars: Enum.map(names, &env_var/1))

      assert {:error, {:malformed, message}} =
               ReservedEnvVarsValidator.validate(definition, @ppl_req)

      assert message =~ "'BAD-20' (block 'Build', job 'Test') and 5 more"
      refute message =~ "'BAD-21'"
    end

    test "lists all violations when there are 20 or fewer" do
      definition = definition(job_env_vars: Enum.map(1..20, &env_var("BAD-#{&1}")))

      assert {:error, {:malformed, message}} =
               ReservedEnvVarsValidator.validate(definition, @ppl_req)

      assert message =~ "'BAD-20' (block 'Build', job 'Test')"
      refute message =~ "more"
    end
  end

  describe "DefinitionReviser.revise_definition/2" do
    test "fails the pipeline as malformed when the YAML sets a reserved name" do
      definition =
        Map.put(definition(), "blocks", [
          %{
            "name" => "Build",
            "task" => %{
              "jobs" => [
                %{
                  "name" => "Test",
                  "commands" => ["echo"],
                  "env_vars" => [env_var("SEMAPHORE_GIT_BRANCH")]
                }
              ]
            }
          }
        ])

      assert DefinitionReviser.revise_definition(definition, @ppl_req) ==
               reserved("SEMAPHORE_GIT_BRANCH (block 'Build', job 'Test')")
    end
  end
end
