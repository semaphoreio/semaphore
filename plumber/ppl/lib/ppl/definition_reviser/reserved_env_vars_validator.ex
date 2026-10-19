defmodule Ppl.DefinitionReviser.ReservedEnvVarsValidator do
  @moduledoc """
  Rejects pipelines whose definition or request parameters set env vars whose names
  are not valid shell identifiers or are reserved for platform-supplied values.
  """

  alias Util.ToTuple

  # Keep in sync with Zebra.Workers.JobRequestFactory.ReservedEnvVars.
  @reserved MapSet.new([
              "SEMAPHORE",
              "SEMAPHORE_AGENT_MACHINE_ENVIRONMENT_TYPE",
              "SEMAPHORE_AGENT_MACHINE_OS_IMAGE",
              "SEMAPHORE_AGENT_MACHINE_TYPE",
              "SEMAPHORE_ARTIFACT_TOKEN",
              "SEMAPHORE_BLOCK_NAME",
              "SEMAPHORE_GIT_BRANCH",
              "SEMAPHORE_GIT_COMMITTER",
              "SEMAPHORE_GIT_COMMIT_AUTHOR",
              "SEMAPHORE_GIT_COMMIT_RANGE",
              "SEMAPHORE_GIT_DIR",
              "SEMAPHORE_GIT_PROVIDER",
              "SEMAPHORE_GIT_PR_BRANCH",
              "SEMAPHORE_GIT_PR_NAME",
              "SEMAPHORE_GIT_PR_NUMBER",
              "SEMAPHORE_GIT_PR_SHA",
              "SEMAPHORE_GIT_PR_SLUG",
              "SEMAPHORE_GIT_REF",
              "SEMAPHORE_GIT_REF_TYPE",
              "SEMAPHORE_GIT_REPO_NAME",
              "SEMAPHORE_GIT_REPO_SLUG",
              "SEMAPHORE_GIT_SHA",
              "SEMAPHORE_GIT_TAG_NAME",
              "SEMAPHORE_GIT_URL",
              "SEMAPHORE_GIT_WORKING_BRANCH",
              "SEMAPHORE_JOB_COUNT",
              "SEMAPHORE_JOB_CREATION_TIME",
              "SEMAPHORE_JOB_ID",
              "SEMAPHORE_JOB_INDEX",
              "SEMAPHORE_JOB_NAME",
              "SEMAPHORE_JOB_ORIGINAL_ID",
              "SEMAPHORE_JOB_RERUN",
              "SEMAPHORE_JOB_TYPE",
              "SEMAPHORE_OIDC_TOKEN",
              "SEMAPHORE_ORGANIZATION_ID",
              "SEMAPHORE_ORGANIZATION_URL",
              "SEMAPHORE_PIPELINE_ARTEFACT_ID",
              "SEMAPHORE_PIPELINE_CREATED_AT",
              "SEMAPHORE_PIPELINE_DONE_AT",
              "SEMAPHORE_PIPELINE_ID",
              "SEMAPHORE_PIPELINE_INIT_DURATION",
              "SEMAPHORE_PIPELINE_NAME",
              "SEMAPHORE_PIPELINE_PROMOTED_BY",
              "SEMAPHORE_PIPELINE_PROMOTION",
              "SEMAPHORE_PIPELINE_QUEUEING_DURATION",
              "SEMAPHORE_PIPELINE_RERUN",
              "SEMAPHORE_PIPELINE_RESULT",
              "SEMAPHORE_PIPELINE_RESULT_REASON",
              "SEMAPHORE_PIPELINE_RUNNING_DURATION",
              "SEMAPHORE_PIPELINE_STARTED_AT",
              "SEMAPHORE_PIPELINE_TOTAL_DURATION",
              "SEMAPHORE_PROJECT_ID",
              "SEMAPHORE_PROJECT_NAME",
              "SEMAPHORE_SNAPSHOT_ID",
              "SEMAPHORE_WORKFLOW_HOOK_SOURCE",
              "SEMAPHORE_WORKFLOW_ID",
              "SEMAPHORE_WORKFLOW_NUMBER",
              "SEMAPHORE_WORKFLOW_RERUN",
              "SEMAPHORE_WORKFLOW_TRIGGERED_BY",
              "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API",
              "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK",
              "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
              "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE",
              "SEMAPHORE_YAML_FILE_PATH"
            ])

  @reserved_pattern ~r/\ASEMAPHORE_PIPELINE_\d+_ARTEFACT_ID\z/

  # Same rule as Secrethub and Zebra; the agent writes names unquoted into `export NAME=value`.
  @valid_name ~r/\A[a-zA-Z_][a-zA-Z0-9_]*\z/

  @reserved_prefix "Reserved environment variables cannot be set: "
  @invalid_prefix "Invalid environment variable names: "
  @max_name_length 40

  # Names are compared case-insensitively because Windows env vars are case-insensitive.
  def reserved?(name) when is_binary(name) do
    name = String.upcase(name)
    MapSet.member?(@reserved, name) or Regex.match?(@reserved_pattern, name)
  end

  def reserved?(_name), do: false

  def valid_name?(name) when is_binary(name), do: Regex.match?(@valid_name, name)
  def valid_name?(_name), do: false

  def validate(definition, ppl_req) do
    names = Enum.uniq(definition_names(definition) ++ parameter_names(ppl_req))

    case Enum.reject(names, fn {name, _location} -> valid_name?(name) end) do
      [] ->
        names
        |> Enum.filter(fn {name, _location} -> reserved?(name) end)
        |> result(definition, @reserved_prefix, &"#{display(&1)} (#{&2})")

      invalid ->
        result(invalid, definition, @invalid_prefix, &"'#{display(&1)}' (#{&2})")
    end
  end

  defp result([], definition, _prefix, _format), do: ToTuple.ok(definition)

  defp result(violations, _definition, prefix, format) do
    entries = Enum.map(violations, fn {name, location} -> format.(name, location) end)
    {:error, {:malformed, prefix <> Enum.join(entries, ", ")}}
  end

  defp definition_names(definition) do
    env_var_names(get_in(definition, ["global_job_config", "env_vars"]), "global_job_config") ++
      container_names(get_in(definition, ["agent", "containers"]), "agent") ++
      promotion_names(definition["promotions"]) ++
      block_names(definition["blocks"], nil) ++
      block_names(definition["after_pipeline"], "after_pipeline")
  end

  defp parameter_names(%{request_args: %{"env_vars" => env_vars}}),
    do: env_var_names(env_vars, "parameters")

  defp parameter_names(_ppl_req), do: []

  defp promotion_names(promotions) when is_list(promotions) do
    Enum.flat_map(promotions, fn promotion ->
      env_var_names(
        get_in(promotion, ["parameters", "env_vars"]),
        "promotion '#{display(promotion["name"])}' parameters"
      )
    end)
  end

  defp promotion_names(_promotions), do: []

  defp block_names(blocks, default_name) when is_list(blocks) do
    Enum.flat_map(blocks, fn block ->
      block_label = "block '#{display(block["name"] || default_name)}'"
      build = block["build"] || %{}

      env_var_names(build["env_vars"], block_label) ++
        container_names(get_in(build, ["agent", "containers"]), block_label) ++
        job_names(build["jobs"], block_label)
    end)
  end

  defp block_names(_blocks, _default_name), do: []

  defp job_names(jobs, block_label) when is_list(jobs) do
    Enum.flat_map(jobs, fn job ->
      job_label = "#{block_label}, job '#{display(job["name"])}'"

      env_var_names(job["env_vars"], job_label) ++
        matrix_names(job["matrix"], "#{job_label} matrix")
    end)
  end

  defp job_names(_jobs, _block_label), do: []

  defp container_names(containers, label) when is_list(containers) do
    Enum.flat_map(containers, fn container ->
      env_var_names(container["env_vars"], "#{label} container '#{display(container["name"])}'")
    end)
  end

  defp container_names(_containers, _label), do: []

  defp matrix_names(matrix, label) when is_list(matrix) do
    for %{"env_var" => name} <- matrix, do: {name, label}
  end

  defp matrix_names(_matrix, _label), do: []

  defp env_var_names(env_vars, label) when is_list(env_vars) do
    for %{"name" => name} <- env_vars, do: {name, label}
  end

  defp env_var_names(_env_vars, _label), do: []

  defp display(text) when is_binary(text) do
    text
    |> String.codepoints()
    |> Enum.filter(&String.valid?/1)
    |> Enum.take(@max_name_length)
    |> Enum.join()
    |> String.replace(~r/[[:cntrl:]]/u, "?")
  end

  defp display(nil), do: ""
  defp display(other), do: other |> inspect() |> display()
end
