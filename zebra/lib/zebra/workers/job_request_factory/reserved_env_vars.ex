defmodule Zebra.Workers.JobRequestFactory.ReservedEnvVars do
  @moduledoc """
  Rejects jobs whose secrets, containers or spec set platform-reserved env vars,
  or env vars whose names are not valid shell identifiers.

  Zebra-owned names never arrive in the spec, so any occurrence is an override.
  Plumber emits its names at most once per pipeline job, so a repeat is an override;
  jobs outside a pipeline get none, so any occurrence there is one too.
  """

  require Logger

  alias Zebra.Workers.JobRequestFactory.FailureReason

  @message_prefix "Reserved environment variables cannot be set: "
  @invalid_message_prefix "Invalid environment variable names: "

  @doc """
  Checks the names Zebra already holds, so a rejected job never checks out a secret
  or mints a token.
  """
  def validate_spec(job, job_type, spec, spec_env_vars) do
    names = spec_names(spec_env_vars) ++ container_names(spec)

    validate_names(job, names, fn ->
      spec_violations(job_type, spec_env_vars) ++ container_violations(spec)
    end)
  end

  @doc """
  The job type whose rule applies to the spec. A debug session of a job outside a
  pipeline gets that job's strict rule, since Plumber never set its env vars.
  """
  def rule_type(job, :debug_job) do
    alias Zebra.Models.{Debug, Job}

    with {:ok, debug} <- Debug.from_jobs() |> Debug.find_by_job_id(job.id),
         {:ok, %{build_id: build_id}} when build_id != nil <- Job.find(debug.debugged_id) do
      :debug_job
    else
      _ -> :project_debug_job
    end
  end

  def rule_type(_job, job_type), do: job_type

  def validate_secrets(job, all_secrets) do
    validate_names(job, secret_names(all_secrets), fn -> secret_violations(all_secrets) end)
  end

  defp validate_names(job, names, violations) do
    case invalid_names(names) do
      [] ->
        validate_reserved(job, violations.())

      invalid ->
        report_invalid(job, invalid)
        {:stop_job_processing, invalid_message(invalid)}
    end
  end

  defp validate_reserved(job, violations) do
    case Enum.uniq(violations) do
      [] ->
        :ok

      violations ->
        report(job, violations)
        {:stop_job_processing, message(violations)}
    end
  end

  defp invalid_names(names) do
    names
    |> Enum.reject(fn
      {name, :container, _label} -> EnvVarPolicy.valid_container_name?(name)
      {name, _kind, _label} -> EnvVarPolicy.valid_name?(name)
    end)
    |> Enum.uniq()
  end

  defp spec_names(spec_env_vars),
    do: Enum.map(spec_env_vars, &{&1["name"], :spec, "job env_vars"})

  defp container_names(spec) do
    Enum.flat_map(spec.agent.containers, fn c ->
      Enum.map(
        c.env_vars,
        &{&1.name, :container, "container '#{FailureReason.clip(c.name)}' env_vars"}
      )
    end)
  end

  defp secret_names(all_secrets) do
    secret_names =
      Enum.flat_map(
        all_secrets.job_secrets ++ List.flatten(all_secrets.container_secrets),
        fn s ->
          Enum.map(s.env_vars, &{&1["name"], :secret, "secret '#{FailureReason.clip(s.name)}'"})
        end
      )

    pull_secret_names =
      Enum.flat_map(all_secrets.image_pull_secrets, fn s ->
        Enum.map(
          s.env_vars,
          &{&1["name"], :image_pull_secret, "image pull secret '#{FailureReason.clip(s.name)}'"}
        )
      end)

    secret_names ++ pull_secret_names
  end

  defp spec_violations(:project_debug_job, env_vars) do
    env_vars
    |> Enum.map(& &1["name"])
    |> Enum.filter(&EnvVarPolicy.reserved?/1)
    |> Enum.map(&{&1, :spec, "job env_vars"})
  end

  defp spec_violations(_job_type, env_vars) do
    names = Enum.map(env_vars, & &1["name"])
    counts = names |> Enum.map(&String.upcase/1) |> Enum.frequencies()

    names
    |> Enum.uniq_by(&String.upcase/1)
    |> Enum.filter(fn name ->
      EnvVarPolicy.zebra_owned?(name) or EnvVarPolicy.shell_startup?(name) or
        (EnvVarPolicy.plumber_owned?(name) and counts[String.upcase(name)] > 1)
    end)
    |> Enum.map(&{&1, :spec, "job env_vars"})
  end

  defp secret_violations(all_secrets) do
    container_secrets = List.flatten(all_secrets.container_secrets)

    Enum.flat_map(all_secrets.job_secrets ++ container_secrets, fn secret ->
      reserved_names(
        secret.env_vars,
        & &1["name"],
        :secret,
        "secret '#{FailureReason.clip(secret.name)}'"
      )
    end) ++
      Enum.flat_map(all_secrets.image_pull_secrets, fn secret ->
        reserved_names(
          secret.env_vars,
          & &1["name"],
          :image_pull_secret,
          "image pull secret '#{FailureReason.clip(secret.name)}'"
        )
      end)
  end

  defp container_violations(spec) do
    Enum.flat_map(spec.agent.containers, fn container ->
      reserved_names(
        container.env_vars,
        & &1.name,
        :container,
        "container '#{FailureReason.clip(container.name)}' env_vars"
      )
    end)
  end

  defp reserved_names(env_vars, name_fun, kind, label) do
    env_vars
    |> Enum.map(name_fun)
    |> Enum.filter(&EnvVarPolicy.reserved?/1)
    |> Enum.map(&{&1, kind, label})
  end

  defp report(job, violations) do
    violations
    |> Enum.map(fn {_name, kind, _label} -> kind end)
    |> Enum.uniq()
    |> Enum.each(fn kind ->
      Watchman.increment({"job_request_factory.reserved_env_vars.rejected", [to_string(kind)]})
    end)

    names = violations |> Enum.map(fn {name, _kind, _label} -> name end) |> Enum.uniq()

    Logger.warning(
      "Reserved env vars rejected job_id=#{job.id} org_id=#{job.organization_id} names=#{Enum.join(names, ",")}"
    )
  end

  defp report_invalid(job, invalid) do
    invalid
    |> Enum.map(fn {_name, kind, _label} -> kind end)
    |> Enum.uniq()
    |> Enum.each(fn kind ->
      Watchman.increment(
        {"job_request_factory.invalid_env_var_names.rejected", [to_string(kind)]}
      )
    end)

    names =
      invalid |> Enum.map(fn {name, _kind, _label} -> FailureReason.clip(name) end) |> Enum.uniq()

    Logger.warning(
      "Invalid env var names rejected job_id=#{job.id} org_id=#{job.organization_id} names=#{inspect(names)}"
    )
  end

  defp invalid_message(invalid) do
    invalid
    |> Enum.map(fn {name, _kind, label} -> "'#{FailureReason.clip(name)}' (#{label})" end)
    |> FailureReason.join(@invalid_message_prefix)
  end

  defp message(violations) do
    violations
    |> Enum.map(fn {name, _kind, label} -> "#{FailureReason.clip(name)} (#{label})" end)
    |> FailureReason.join(@message_prefix)
  end
end
