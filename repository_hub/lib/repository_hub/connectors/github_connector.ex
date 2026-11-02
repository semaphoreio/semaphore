defmodule RepositoryHub.GithubConnector do
  # credo:disable-for-this-file

  defstruct [:git_repository, :repository, :token]

  alias __MODULE__

  @type t :: %GithubConnector{}

  alias RepositoryHub.{
    Model,
    Toolkit,
    GithubClient,
    GithubAdapter,
    UserClient
  }

  import Toolkit

  @spec setup(Ecto.UUID.t(), String.t()) :: Toolkit.tupled_result(t())
  def setup(repository_id, token) do
    Model.RepositoryQuery.get_by_id(repository_id)
    |> unwrap(fn repository ->
      Model.GitRepository.from_github(repository.url)
      |> unwrap(fn git_repository ->
        %GithubConnector{
          repository: repository,
          git_repository: git_repository,
          token: token
        }
        |> wrap
      end)
    end)
  end

  def update_repository_url(connector, url, target_token, user_id) do
    connector.git_repository
    |> Model.GitRepository.equal?(url)
    |> unwrap(fn
      true ->
        wrap(unchanged(connector))

      false ->
        connector.git_repository
        |> Model.GitRepository.did_host_change?(url)
        |> unwrap(fn
          true ->
            fail_with(:precondition, "Changing git host is not supported yet.")

          false when user_id == "" ->
            fail_with(:precondition, "Changing the repository URL requires a known requester.")

          false ->
            UserClient.describe(user_id)
            |> unwrap(&change_url_as_requester(connector, url, target_token, &1))
        end)
    end)
  end

  defp change_url_as_requester(_connector, _url, _target_token, %{user: %{creation_source: :SERVICE_ACCOUNT}}) do
    fail_with(:precondition, "Service accounts can't change the repository URL.")
  end

  defp change_url_as_requester(connector, url, target_token, requester) do
    github_app? = connector.repository.integration_type == "github_app"
    fallback? = github_app? and target_token == ""
    token = if fallback?, do: connector.token, else: target_token

    {permission, denied_message} =
      if github_app?,
        do: {"push", "Write permissions are required on the repository to change the project's repository URL."},
        else: {"admin", "Admin permissions are required on the repository to change the project's repository URL."}

    with {:ok, github_repository} <- can_change_url?(connector, url, token, fallback?),
         {:ok, git_repository} <- Model.GitRepository.from_github(url),
         {:ok, %{^permission => true}} <-
           GithubAdapter.repository_permissions(
             requester.user_id,
             %{repo_owner: git_repository.owner, repo_name: git_repository.repo},
             token,
             "Connect your GitHub account to Semaphore to change the repository URL."
           ) do
      prepare_url_change(connector, url, token, github_repository)
    else
      {:ok, _permissions} ->
        fail_with(:precondition, denied_message)

      error ->
        error
    end
  end

  defp can_change_url?(connector, url, token, fallback?) do
    Model.GitRepository.from_github(url)
    |> unwrap(fn git_repository ->
      GithubClient.find_repository(
        %{
          repo_owner: git_repository.owner,
          repo_name: git_repository.repo
        },
        token: token
      )
      |> tap(fn result ->
        if fallback?,
          do: Watchman.increment({"github_app.update_url.target_token_fallback", [to_string(elem(result, 0))]})
      end)
      |> unwrap_error(fn
        _ when fallback? ->
          fail_with(
            :precondition,
            "Semaphore GitHub App is not installed on #{git_repository.owner}, or it has no access to #{git_repository.repo}."
          )

        error ->
          error(error)
      end)
    end)
    |> unwrap(fn
      %{with_admin_access?: true} = github_repository ->
        wrap(github_repository)

      github_repository when connector.repository.integration_type == "github_app" ->
        wrap(github_repository)

      _ ->
        fail_with(:precondition, "Admin permissions are required on the repository to add the project to Semaphore")
    end)
  end

  defp unchanged(connector) do
    %{connector: connector, repository_changes: %{}, new_deploy_key: nil, old_resources: nil, created: nil}
  end

  defp prepare_url_change(connector, url, target_token, github_repository) do
    Model.GitRepository.from_github(url)
    |> unwrap(fn new_git_repository ->
      repository_changes = %{
        name: new_git_repository.repo,
        owner: new_git_repository.owner,
        url: new_git_repository.ssh_git_url,
        remote_id: github_repository.id,
        private: github_repository.is_private?,
        default_branch: github_repository.default_branch,
        connected: true
      }

      if github_repository.id != connector.repository.remote_id do
        create_target_resources(connector, new_git_repository, target_token, repository_changes)
      else
        wrap(%{unchanged(connector) | repository_changes: repository_changes})
      end
    end)
  end

  defp create_target_resources(connector, new_git_repository, token, repository_changes) do
    repository = connector.repository

    created = %{
      label: "created",
      owner: new_git_repository.owner,
      repo: new_git_repository.repo,
      token: token,
      hook_id: nil,
      deploy_key: nil
    }

    with {:ok, {webhook, secret_enc}} <- create_webhook(repository, new_git_repository, token),
         created = %{created | hook_id: webhook.id},
         {:ok, new_deploy_key} <- create_deploy_key(repository, new_git_repository, token, created) do
      wrap(%{
        connector: connector,
        repository_changes: Map.merge(repository_changes, %{hook_id: webhook.id, hook_secret_enc: secret_enc}),
        new_deploy_key: new_deploy_key,
        old_resources: capture_old_resources(connector),
        created: %{created | deploy_key: %{remote_id: new_deploy_key.remote_id}}
      })
    end
  end

  def apply_url_change(%{repository_changes: changes} = change) when map_size(changes) == 0 do
    wrap(change.connector.repository)
  end

  def apply_url_change(change) do
    Model.RepositoryQuery.update(change.connector.repository, change.repository_changes, returning: true)
    |> unwrap(fn repository ->
      replace_deploy_key(change)
      |> unwrap(fn _ -> wrap(repository) end)
    end)
  end

  defp replace_deploy_key(%{new_deploy_key: nil}), do: wrap(nil)

  defp replace_deploy_key(%{old_resources: %{deploy_key: %{id: old_id}}} = change) do
    Model.DeployKeyQuery.delete(old_id)
    |> unwrap(fn _ -> Model.DeployKeyQuery.insert(change.new_deploy_key) end)
  end

  defp replace_deploy_key(change), do: Model.DeployKeyQuery.insert(change.new_deploy_key)

  defp capture_old_resources(connector) do
    old_deploy_key =
      case Model.DeployKeyQuery.get_by_repository_id(connector.repository.id) do
        {:ok, deploy_key} -> %{id: deploy_key.id, remote_id: deploy_key.remote_id}
        {:error, _} -> nil
      end

    %{
      label: "old",
      owner: connector.git_repository.owner,
      repo: connector.git_repository.repo,
      token: connector.token,
      hook_id: connector.repository.hook_id,
      deploy_key: old_deploy_key
    }
  end

  def remove_github_resources(nil), do: :ok

  def remove_github_resources(resources) do
    remove_webhook(resources)
    remove_deploy_key(resources)
    :ok
  end

  defp remove_webhook(%{token: ""}), do: :ok
  defp remove_webhook(%{hook_id: nil}), do: :ok

  defp remove_webhook(resources) do
    GithubClient.remove_webhook(
      %{repo_owner: resources.owner, repo_name: resources.repo, webhook_id: resources.hook_id},
      token: resources.token
    )
    |> unwrap_error(&log_removal_failure("webhook", resources, &1))
  rescue
    error -> log_removal_failure("webhook", resources, error)
  end

  defp remove_deploy_key(%{token: ""}), do: :ok
  defp remove_deploy_key(%{deploy_key: nil}), do: :ok

  defp remove_deploy_key(%{deploy_key: deploy_key} = resources) do
    GithubClient.remove_deploy_key(
      %{repo_owner: resources.owner, repo_name: resources.repo, key_id: deploy_key.remote_id},
      token: resources.token
    )
    |> unwrap_error(&log_removal_failure("deploy_key", resources, &1))
  rescue
    error -> log_removal_failure("deploy_key", resources, error)
  end

  defp log_removal_failure(kind, resources, reason) do
    log_warn([
      "failed to remove #{resources.label} #{kind} for #{resources.owner}/#{resources.repo} after url change: #{inspect(reason)}"
    ])

    Watchman.increment({"github_app.update_url.#{resources.label}_#{kind}_removal_failed", []})
  end

  defp create_webhook(repository, git_repository, token) do
    params = %{
      repo_owner: git_repository.owner,
      repo_name: git_repository.repo,
      url: GithubClient.Webhook.url(repository.project_id),
      events: GithubClient.Webhook.events()
    }

    GithubClient.find_webhook(params, token: token)
    |> unwrap(fn existing ->
      GithubClient.remove_webhook(Map.put(params, :webhook_id, existing.id), token: token)
    end)

    {:ok, {secret, secret_enc}} = Model.Repositories.generate_hook_secret(repository)

    params
    |> Map.put(:secret, secret)
    |> GithubClient.create_webhook(token: token)
    |> unwrap(fn webhook -> wrap({webhook, secret_enc}) end)
  end

  defp create_deploy_key(repository, git_repository, token, created) do
    {private_key, public_key} = Model.DeployKeys.generate_private_public_key_pair()

    {:ok, private_key_enc} =
      RepositoryHub.Encryptor.encrypt(
        RepositoryHub.DeployKeyEncryptor,
        private_key,
        "semaphore-#{repository.project_id}"
      )

    GithubClient.create_deploy_key(
      %{
        repo_owner: git_repository.owner,
        repo_name: git_repository.repo,
        title: "semaphore-#{git_repository.owner}-#{git_repository.repo}",
        key: public_key,
        read_only: true
      },
      token: token
    )
    |> unwrap(fn remote_key ->
      wrap(%{
        public_key: public_key,
        private_key_enc: private_key_enc,
        deployed: true,
        remote_id: remote_key.id,
        project_id: repository.project_id,
        repository_id: repository.id
      })
    end)
    |> unwrap_error(fn reason ->
      remove_github_resources(created)
      error(reason)
    end)
  end
end
