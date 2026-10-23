defmodule EnvVarPolicy do
  @moduledoc """
  Names of the environment variables Semaphore supplies to jobs, and the rules
  user-defined variable names must follow.
  """

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

  @plumber_owned_pattern ~r/\ASEMAPHORE_PIPELINE_\d+_ARTEFACT_ID\z/

  # The agent writes job env var names unquoted into `export NAME=value`.
  @valid_name ~r/\A[a-zA-Z_][a-zA-Z0-9_]*\z/
  # Service container env vars go into the docker-compose file instead, where dotted
  # names like `discovery.type` are common.
  @valid_container_name ~r/\A[a-zA-Z_][a-zA-Z0-9_.-]*\z/

  @max_name_length 64

  @doc """
  Whether Semaphore supplies a variable with this name.

  Names are compared case-insensitively because Windows env vars are case-insensitive.
  """
  def reserved?(name), do: zebra_owned?(name) or plumber_owned?(name)

  @doc "Whether Zebra injects this name into every job it builds."
  def zebra_owned?(name) when is_binary(name),
    do: MapSet.member?(@zebra_owned, String.upcase(name))

  def zebra_owned?(_name), do: false

  @doc "Whether Plumber injects this name into the jobs of a pipeline."
  def plumber_owned?(name) when is_binary(name) do
    name = String.upcase(name)
    MapSet.member?(@plumber_owned, name) or Regex.match?(@plumber_owned_pattern, name)
  end

  def plumber_owned?(_name), do: false

  @doc "Whether the name is a shell identifier, as job env var names must be."
  def valid_name?(name) when is_binary(name), do: Regex.match?(@valid_name, name)
  def valid_name?(_name), do: false

  @doc "Whether the name is allowed for a service container env var."
  def valid_container_name?(name) when is_binary(name),
    do: Regex.match?(@valid_container_name, name)

  def valid_container_name?(_name), do: false

  @doc """
  Prepares a user-chosen name for an error message: keeps at most
  #{@max_name_length} codepoints, drops invalid UTF-8 and replaces control
  characters such as newlines with "?".
  """
  def clip(name) when is_binary(name) do
    name
    |> String.codepoints()
    |> Enum.filter(&String.valid?/1)
    |> Enum.take(@max_name_length)
    |> Enum.join()
    |> String.replace(~r/[[:cntrl:]]/u, "?")
  end
end
