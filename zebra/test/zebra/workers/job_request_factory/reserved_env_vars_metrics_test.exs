defmodule Zebra.Workers.JobRequestFactory.ReservedEnvVarsMetricsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mock

  alias Semaphore.Jobs.V1alpha.Job.Spec
  alias Zebra.Workers.JobRequestFactory.{JobRequest, ReservedEnvVars, Secrets}

  @job %Zebra.Models.Job{id: Ecto.UUID.generate(), organization_id: Ecto.UUID.generate()}

  @no_secrets %Secrets{job_secrets: [], image_pull_secrets: [], container_secrets: []}

  @reserved_metric "job_request_factory.reserved_env_vars.rejected"
  @invalid_metric "job_request_factory.invalid_env_var_names.rejected"

  defp env_vars(names), do: Enum.map(names, &JobRequest.env_var(&1, "value"))

  defp secret(name, env_var_names),
    do: %Secrets.Secret{name: name, env_vars: env_vars(env_var_names), files: []}

  test "counts reserved-name rejections once per source kind" do
    container =
      Spec.Agent.Container.new(
        name: "db",
        env_vars: [
          Spec.EnvVar.new(name: "SEMAPHORE_JOB_ID", value: "x"),
          Spec.EnvVar.new(name: "SEMAPHORE_JOB_NAME", value: "x")
        ]
      )

    spec = Spec.new(agent: Spec.Agent.new(containers: [container]))

    secrets = %{
      @no_secrets
      | job_secrets: [secret("deploy", ["SEMAPHORE_GIT_SHA", "SEMAPHORE_GIT_BRANCH"])],
        image_pull_secrets: [secret("registry", ["SEMAPHORE_OIDC_TOKEN"])]
    }

    with_mock Watchman, [:passthrough], increment: fn _ -> :ok end do
      capture_log(fn ->
        ReservedEnvVars.validate_spec(@job, :pipeline_job, spec, env_vars(["SEMAPHORE_GIT_URL"]))
        ReservedEnvVars.validate_secrets(@job, secrets)
      end)

      for kind <- ["spec", "container", "secret", "image_pull_secret"] do
        assert_called_exactly(Watchman.increment({@reserved_metric, [kind]}), 1)
      end

      refute called(Watchman.increment({@invalid_metric, :_}))
    end
  end

  test "counts invalid-name rejections per source kind without counting them as reserved" do
    secrets = %{@no_secrets | job_secrets: [secret("deploy", ["BAD NAME"])]}

    with_mock Watchman, [:passthrough], increment: fn _ -> :ok end do
      capture_log(fn ->
        ReservedEnvVars.validate_spec(
          @job,
          :pipeline_job,
          Spec.new(agent: Spec.Agent.new()),
          env_vars(["1ST"])
        )

        ReservedEnvVars.validate_secrets(@job, secrets)
      end)

      assert_called_exactly(Watchman.increment({@invalid_metric, ["spec"]}), 1)
      assert_called_exactly(Watchman.increment({@invalid_metric, ["secret"]}), 1)
      refute called(Watchman.increment({@reserved_metric, :_}))
    end
  end

  test "emits nothing for a clean job" do
    with_mock Watchman, [:passthrough], increment: fn _ -> :ok end do
      assert ReservedEnvVars.validate_spec(
               @job,
               :pipeline_job,
               Spec.new(agent: Spec.Agent.new()),
               env_vars(["IGOR"])
             ) ==
               :ok

      assert ReservedEnvVars.validate_secrets(@job, @no_secrets) == :ok

      refute called(Watchman.increment(:_))
    end
  end
end
