defmodule Front.Models.FetchingJob do
  @moduledoc """
  Module encapsulates all functions needed to define the job used for fetching
  the yaml files needed in workflow editor from the git repository.
  """

  alias Front.Models.OrganizationSettings
  alias InternalApi.ServerFarm.Job.JobSpec
  alias Front.Models.Job

  require Logger

  def start_fetching_job(params) do
    with {:ok, agent} <- get_agent(params.project),
         {:ok, job_spec} <- create_job_spec(agent, params),
         {:ok, job} <- Job.create(job_spec, params) do
      {:ok, job.id}
    else
      error ->
        Logger.error(
          Enum.join(
            [
              "Could not create fetching job",
              "project: #{params.project.id}",
              "branch: #{params.target_branch}",
              "user: #{params.user_id}",
              "error: #{inspect(error)}"
            ],
            ", "
          )
        )

        {:error, :fetching_job_creation_failed}
    end
  end

  defp get_agent(project) do
    case OrganizationSettings.fetch(project.organization_id) do
      {:ok, settings} -> decide_on_agent(settings)
      error -> {:error, :fetch_agent, error}
    end
  end

  defp decide_on_agent(%{"custom_machine_type" => type, "custom_os_image" => os_image})
       when is_binary(type) and type != "" do
    {:ok, %{type: type, os_image: os_image}}
  end

  defp decide_on_agent(%{"plan_machine_type" => type, "plan_os_image" => os_image})
       when is_binary(type) and type != "" do
    {:ok, %{type: type, os_image: os_image}}
  end

  defp decide_on_agent(_seetings), do: {:error, :settings_without_agent_def}

  defp create_job_spec(agent, params) do
    {:ok,
     %JobSpec{
       job_name: "Workflow editor fetching files * #{params.project.name} * #{params.hook.name}",
       agent: %JobSpec.Agent{
         machine: %JobSpec.Agent.Machine{
           os_image: agent.os_image,
           type: agent.type
         },
         containers: [],
         image_pull_secrets: []
       },
       secrets: [],
       env_vars: [],
       files: [],
       commands: generate_commands(params),
       epilogue_always_commands: [],
       epilogue_on_pass_commands: [],
       epilogue_on_fail_commands: [],
       priority: 95,
       execution_time_limit: 10
     }}
  end

  defp generate_commands(params) do
    [
      "export SEMAPHORE_GIT_DEPTH=5",
      configure_env_vars_for_checkout(params),
      "checkout",
      "artifact push job .semaphore -d .workflow_editor/.semaphore"
    ]
    |> List.flatten()
  end

  defp configure_env_vars_for_checkout(params) do
    case params.hook.type do
      "branch" -> set_branch_env_vars(params.hook)
      "tag" -> set_tag_env_vars(params.hook)
      "pr" -> set_pr_env_vars(params.hook)
      :skip -> []
    end
  end

  defp set_branch_env_vars(hook) do
    [
      "export SEMAPHORE_GIT_REF_TYPE=branch",
      "export SEMAPHORE_GIT_BRANCH=#{hook.branch_name}",
      "export SEMAPHORE_GIT_SHA=#{hook.head_commit_sha}"
    ]
  end

  defp set_tag_env_vars(hook) do
    [
      "export SEMAPHORE_GIT_REF_TYPE=tag",
      "export SEMAPHORE_GIT_TAG_NAME=#{hook.tag_name}",
      "export SEMAPHORE_GIT_SHA=#{hook.head_commit_sha}"
    ]
  end

  defp set_pr_env_vars(hook) do
    [
      "export SEMAPHORE_GIT_REF_TYPE=pull-request",
      "export SEMAPHORE_GIT_REF=refs/pull/#{hook.pr_number}/merge",
      "export SEMAPHORE_GIT_SHA=#{hook.head_commit_sha}"
    ]
  end
end
