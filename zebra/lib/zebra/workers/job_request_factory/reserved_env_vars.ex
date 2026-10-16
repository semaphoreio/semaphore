defmodule Zebra.Workers.JobRequestFactory.ReservedEnvVars do
  @moduledoc """
  Rejects jobs whose secrets, containers or spec set platform-reserved env vars.

  Zebra-owned names never arrive in the spec, so any occurrence is an override.
  Plumber emits its names at most once per pipeline job, so a repeat is an override;
  jobs outside a pipeline get none, so any occurrence there is one too.
  """

  require Logger

  @zebra_owned MapSet.new([
                 "SEMAPHORE",
                 "SEMAPHORE_PROJECT_NAME",
                 "SEMAPHORE_PROJECT_ID",
                 "SEMAPHORE_JOB_NAME",
                 "SEMAPHORE_JOB_ID",
                 "SEMAPHORE_JOB_CREATION_TIME",
                 "SEMAPHORE_JOB_TYPE",
                 "SEMAPHORE_AGENT_MACHINE_TYPE",
                 "SEMAPHORE_AGENT_MACHINE_OS_IMAGE",
                 "SEMAPHORE_AGENT_MACHINE_ENVIRONMENT_TYPE",
                 "SEMAPHORE_ORGANIZATION_URL",
                 "SEMAPHORE_ARTIFACT_TOKEN",
                 "SEMAPHORE_OIDC_TOKEN",
                 "SEMAPHORE_GIT_PROVIDER",
                 "SEMAPHORE_GIT_URL",
                 "SEMAPHORE_GIT_REPO_NAME",
                 "SEMAPHORE_GIT_DIR",
                 "SEMAPHORE_GIT_SHA",
                 "SEMAPHORE_GIT_REPO_SLUG",
                 "SEMAPHORE_GIT_REF",
                 "SEMAPHORE_GIT_COMMIT_RANGE",
                 "SEMAPHORE_GIT_BRANCH",
                 "SEMAPHORE_GIT_WORKING_BRANCH",
                 "SEMAPHORE_GIT_REF_TYPE",
                 "SEMAPHORE_GIT_TAG_NAME",
                 "SEMAPHORE_GIT_PR_SLUG",
                 "SEMAPHORE_GIT_PR_SHA",
                 "SEMAPHORE_GIT_PR_NUMBER",
                 "SEMAPHORE_GIT_PR_NAME",
                 "SEMAPHORE_GIT_PR_BRANCH"
               ])

  @plumber_owned MapSet.new([
                   "SEMAPHORE_WORKFLOW_ID",
                   "SEMAPHORE_WORKFLOW_NUMBER",
                   "SEMAPHORE_WORKFLOW_RERUN",
                   "SEMAPHORE_WORKFLOW_TRIGGERED_BY",
                   "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
                   "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE",
                   "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API",
                   "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
                   "SEMAPHORE_WORKFLOW_HOOK_SOURCE",
                   "SEMAPHORE_PIPELINE_ID",
                   "SEMAPHORE_PIPELINE_NAME",
                   "SEMAPHORE_PIPELINE_ARTEFACT_ID",
                   "SEMAPHORE_PIPELINE_RERUN",
                   "SEMAPHORE_PIPELINE_PROMOTION",
                   "SEMAPHORE_PIPELINE_PROMOTED_BY",
                   "SEMAPHORE_PIPELINE_TOTAL_DURATION",
                   "SEMAPHORE_PIPELINE_INIT_DURATION",
                   "SEMAPHORE_PIPELINE_QUEUEING_DURATION",
                   "SEMAPHORE_PIPELINE_RUNNING_DURATION",
                   "SEMAPHORE_PIPELINE_CREATED_AT",
                   "SEMAPHORE_PIPELINE_STARTED_AT",
                   "SEMAPHORE_PIPELINE_DONE_AT",
                   "SEMAPHORE_PIPELINE_RESULT",
                   "SEMAPHORE_PIPELINE_RESULT_REASON",
                   "SEMAPHORE_BLOCK_NAME",
                   "SEMAPHORE_GIT_COMMIT_AUTHOR",
                   "SEMAPHORE_GIT_COMMITTER",
                   "SEMAPHORE_ORGANIZATION_ID",
                   "SEMAPHORE_SNAPSHOT_ID",
                   "SEMAPHORE_YAML_FILE_PATH",
                   "SEMAPHORE_JOB_COUNT",
                   "SEMAPHORE_JOB_INDEX",
                   "SEMAPHORE_JOB_RERUN",
                   "SEMAPHORE_JOB_ORIGINAL_ID"
                 ])

  @plumber_owned_pattern ~r/^SEMAPHORE_PIPELINE_\d+_ARTEFACT_ID$/

  @message_prefix "Reserved environment variables cannot be set: "
  # failure_reason is a varchar(255) column, and Postgres counts codepoints, not graphemes
  @max_message_length 255
  @max_name_length 40

  # Names are compared case-insensitively because Windows env vars are case-insensitive.
  def reserved?(name), do: zebra_owned?(name) or plumber_owned?(name)

  defp zebra_owned?(name), do: MapSet.member?(@zebra_owned, String.upcase(name))

  defp plumber_owned?(name) do
    name = String.upcase(name)
    MapSet.member?(@plumber_owned, name) or Regex.match?(@plumber_owned_pattern, name)
  end

  def validate(job, job_type, spec, spec_env_vars, all_secrets) do
    violations =
      spec_violations(job_type, spec_env_vars) ++
        secret_violations(all_secrets) ++
        container_violations(spec)

    case Enum.uniq(violations) do
      [] ->
        :ok

      violations ->
        report(job, violations)
        {:stop_job_processing, message(violations)}
    end
  end

  defp spec_violations(:project_debug_job, env_vars) do
    env_vars
    |> Enum.map(& &1["name"])
    |> Enum.filter(&reserved?/1)
    |> Enum.map(&{&1, :spec, "job env_vars"})
  end

  defp spec_violations(_job_type, env_vars) do
    names = Enum.map(env_vars, & &1["name"])
    counts = names |> Enum.map(&String.upcase/1) |> Enum.frequencies()

    names
    |> Enum.uniq_by(&String.upcase/1)
    |> Enum.filter(fn name ->
      zebra_owned?(name) or (plumber_owned?(name) and counts[String.upcase(name)] > 1)
    end)
    |> Enum.map(&{&1, :spec, "job env_vars"})
  end

  defp secret_violations(all_secrets) do
    container_secrets = List.flatten(all_secrets.container_secrets)

    Enum.flat_map(all_secrets.job_secrets ++ container_secrets, fn secret ->
      reserved_names(secret.env_vars, & &1["name"], :secret, "secret '#{clip(secret.name)}'")
    end) ++
      Enum.flat_map(all_secrets.image_pull_secrets, fn secret ->
        reserved_names(
          secret.env_vars,
          & &1["name"],
          :image_pull_secret,
          "image pull secret '#{clip(secret.name)}'"
        )
      end)
  end

  defp container_violations(spec) do
    Enum.flat_map(spec.agent.containers, fn container ->
      reserved_names(
        container.env_vars,
        & &1.name,
        :container,
        "container '#{clip(container.name)}' env_vars"
      )
    end)
  end

  defp reserved_names(env_vars, name_fun, kind, label) do
    env_vars
    |> Enum.map(name_fun)
    |> Enum.filter(&reserved?/1)
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

  defp message(violations) do
    entries = Enum.map(violations, fn {name, _kind, label} -> "#{clip(name)} (#{label})" end)
    total = length(entries)

    total..1//-1
    |> Enum.map(&render(Enum.take(entries, &1), total - &1))
    |> Enum.find(&(codepoint_length(&1) <= @max_message_length))
    |> case do
      nil -> entries |> Enum.take(1) |> render(total - 1) |> take_codepoints(@max_message_length)
      message -> message
    end
  end

  defp clip(text), do: take_codepoints(text, @max_name_length)

  defp take_codepoints(text, count) do
    text
    |> String.codepoints()
    |> Enum.filter(&String.valid?/1)
    |> Enum.take(count)
    |> Enum.join()
  end

  defp codepoint_length(text), do: text |> String.codepoints() |> length()

  defp render(entries, 0), do: @message_prefix <> Enum.join(entries, ", ")
  defp render(entries, remaining), do: render(entries, 0) <> " and #{remaining} more"
end
