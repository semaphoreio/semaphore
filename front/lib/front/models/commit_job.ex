defmodule Front.Models.CommitJob do
  @moduledoc """
  Module encapsulates all functions needed to define the job used for commiting
  the changes made in workflow editor.
  """

  require Logger

  alias Front.Models.User
  alias Front.Models.OrganizationSettings
  alias Front.Models.RepositoryIntegrator
  alias InternalApi.ServerFarm.Job.JobSpec
  alias InternalApi.Repository.CommitRequest.Change.Action

  def get_agent(project) do
    case OrganizationSettings.fetch(project.organization_id) do
      {:ok, settings} -> decide_on_agent(settings)
      error -> {:error, :fetch_agent, error}
    end
  end

  defp decide_on_agent(%{"custom_machine_type" => type, "custom_os_image" => os_image})
       when is_binary(type) and type != "" do
    {:ok, %{type: type, os_image: os_image}}
  end

  defp decide_on_agent(%{"custom_machine_type" => type})
       when is_binary(type) and type != "" do
    {:ok, %{type: type, os_image: ""}}
  end

  defp decide_on_agent(%{"plan_machine_type" => type, "plan_os_image" => os_image})
       when is_binary(type) and type != "" do
    {:ok, %{type: type, os_image: os_image}}
  end

  defp decide_on_agent(_seetings), do: {:error, :settings_without_agent_def}

  def get_git_credentials(project, user_id) do
    case project.integration_type do
      :GITHUB_OAUTH_TOKEN ->
        get_creds_from_repository_integrator(project, user_id, "x-oauth-token")

      :GITHUB_APP ->
        get_creds_from_repository_integrator(project, user_id, "x-access-token")

      :BITBUCKET ->
        get_creds_from_user_service(project, user_id, "x-token-auth")

      :GITLAB ->
        get_creds_from_user_service(project, user_id, "oauth2")

      :GIT ->
        {:ok, :GIT}
    end
  end

  defp get_creds_from_repository_integrator(project, user_id, git_username) do
    case RepositoryIntegrator.get_repository_token(project, user_id) do
      {:ok, token} -> {:ok, %{username: git_username, token: token}}
      error -> {:error, :token_from_repo_integrator, error}
    end
  end

  defp get_creds_from_user_service(project, user_id, git_username) do
    case User.get_repository_token(project, user_id) do
      {:ok, token} -> {:ok, %{username: git_username, token: token}}
      error -> {:error, :token_from_user_svc, error}
    end
  end

  def create_job_spec(agent, :GIT, params) do
    {:ok,
     %JobSpec{
       job_name: "Commiting changes from workflow editor to branch #{params.target_branch}",
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
       files: modified_files(params.changes),
       commands: generate_git_commands(params),
       epilogue_always_commands: [],
       epilogue_on_pass_commands: [],
       epilogue_on_fail_commands: [],
       priority: 95,
       execution_time_limit: 10
     }}
  end

  def create_job_spec(agent, creds, params) do
    {:ok,
     %JobSpec{
       job_name: "Commiting changes from workflow editor to branch #{params.target_branch}",
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
       files: files_for_creds(creds) ++ modified_files(params.changes),
       commands: generate_commands(params),
       epilogue_always_commands: [],
       epilogue_on_pass_commands: [],
       epilogue_on_fail_commands: [],
       priority: 95,
       execution_time_limit: 10
     }}
  end

  defp files_for_creds(creds) do
    [
      %JobSpec.File{
        path: ".workflow_editor/git_username.txt",
        content: Base.encode64(creds.username)
      },
      %JobSpec.File{
        path: ".workflow_editor/git_password.txt",
        content: Base.encode64(creds.token)
      }
    ]
  end

  defp modified_files(changes) do
    Enum.reduce(changes, [], fn change, acc ->
      if change.action != Action.value(:DELETE_FILE) do
        file = %JobSpec.File{
          path: ".changed_files/#{change.file.path}",
          content: Base.encode64(change.file.content)
        }

        acc ++ [file]
      else
        acc
      end
    end)
  end

  defp generate_commands(params) do
    [
      # Read git credentials from files
      "export GIT_USERNAME=$(cat .workflow_editor/git_username.txt)",
      "export GIT_PASSWORD=$(cat .workflow_editor/git_password.txt)",
      # Prepare URL used for pushing with temporary user access token as a credential
      "export GIT_REPO_URL=\"${SEMAPHORE_GIT_URL/://}\"",
      "export GIT_REPO_URL=\"${GIT_REPO_URL/git@/https:\/\/$GIT_USERNAME:$GIT_PASSWORD@}\"",
      # Configure the branch that checkout should use
      "export SEMAPHORE_GIT_BRANCH=#{params.initial_branch}",
      # Clone repository using the read-only deploy key
      "checkout",
      # switch to a new branch if user configured a different target branch
      configure_target_branch(params.initial_branch, params.target_branch),
      # Add modified files and remove deleted ones
      add_commands_for_modified_files(params),
      add_commands_for_deleted_files(params),
      # Configure the user to be author of the changes
      "git config --global user.name #{params.user.name}",
      "git config --global user.email #{params.user.email}",
      # Create commit with changes
      "git add .",
      "git commit -m \"#{params.commit_message}\"",
      # Push commit to remote repository
      "git push $GIT_REPO_URL HEAD",
      # save the new commit sha in artifacts
      "git rev-parse HEAD > commit_sha.val",
      "artifact push job commit_sha.val -d .workflow_editor/commit_sha.val"
    ]
    |> List.flatten()
    |> Enum.filter(fn elem -> elem != :skip end)
  end

  defp generate_git_commands(params) do
    [
      # Configure the branch that checkout should use
      "export SEMAPHORE_GIT_BRANCH=#{params.initial_branch}",
      # Clone repository using the read-only deploy key
      "checkout",
      # switch to a new branch if user configured a different target branch
      configure_git_target_branch(params.initial_branch, params.target_branch),
      add_commands_for_modified_files(params),
      add_commands_for_deleted_files(params),
      # Configure the user to be author of the changes
      "git config --global user.name #{params.user.name}",
      "git config --global user.email #{params.user.email}",
      # Create commit with changes
      "git add .",
      "git commit -m \"#{params.commit_message}\"",
      # Push commit to remote repository
      "git push $SEMAPHORE_GIT_URL #{params.target_branch} --force",
      # save the new commit sha in artifacts
      "git rev-parse HEAD > commit_sha.val",
      "artifact push job commit_sha.val -d .workflow_editor/commit_sha.val"
    ]
    |> List.flatten()
    |> Enum.filter(fn elem -> elem != :skip end)
  end

  defp configure_git_target_branch(initial, target) do
    if initial == target do
      :skip
    else
      [
        # Fetch remote branches
        "git fetch origin #{target} || true",
        # Check if branch exists on remote
        "if git show-ref --verify --quiet refs/remotes/origin/#{target}; then",
        "  git checkout -B #{target} origin/#{target}",
        "else",
        "  git checkout -B #{target} #{initial}",
        "fi"
      ]
    end
  end

  defp configure_target_branch(initial, target) do
    if initial == target do
      :skip
    else
      ~s[git checkout -b #{target}]
    end
  end

  defp add_commands_for_modified_files(params) do
    Enum.reduce(params.changes, [], fn change, acc ->
      if change.action != Action.value(:DELETE_FILE) do
        dir_path = Path.dirname(change.file.path)

        acc ++
          ["mkdir -p ./#{dir_path}"] ++
          ["mv ../.changed_files/#{change.file.path} ./#{change.file.path}"]
      else
        acc
      end
    end)
  end

  defp add_commands_for_deleted_files(params) do
    Enum.reduce(params.changes, [], fn change, acc ->
      if change.action == Action.value(:DELETE_FILE) do
        acc ++ ["rm #{change.file.path} || true"]
      else
        acc
      end
    end)
  end
end
