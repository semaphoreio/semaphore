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

  alias Ecto.Multi

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
        wrap(connector)

      false ->
        connector.git_repository
        |> Model.GitRepository.did_host_change?(url)
        |> unwrap(fn
          true ->
            fail_with(:precondition, "Changing git host is not supported yet.")

          false when connector.repository.integration_type != "github_app" ->
            connector
            |> can_change_url?(url, target_token, false)
            |> unwrap(&update_repository_url_impl(connector, url, target_token, &1))

          false when user_id == "" ->
            fail_with(:precondition, "Changing the repository URL requires a known requester.")

          false ->
            UserClient.describe(user_id)
            |> unwrap(&change_url_as_requester(connector, url, target_token, &1))
        end)
    end)
  end

  defp change_url_as_requester(connector, url, _target_token, %{user: %{creation_source: :SERVICE_ACCOUNT}}) do
    connector
    |> can_change_url?(url, connector.token, false)
    |> unwrap_error(fn _ ->
      fail_with(
        :precondition,
        "Service accounts can only change the repository URL to a repository that the project's current GitHub App installation can access."
      )
    end)
    |> unwrap(&update_repository_url_impl(connector, url, connector.token, &1))
  end

  defp change_url_as_requester(connector, url, target_token, requester) do
    fallback? = target_token == ""
    token = if fallback?, do: connector.token, else: target_token

    with {:ok, github_repository} <- can_change_url?(connector, url, token, fallback?),
         {:ok, git_repository} <- Model.GitRepository.from_github(url),
         {:ok, %{"push" => true}} <-
           GithubAdapter.repository_permissions(
             requester.user_id,
             %{repo_owner: git_repository.owner, repo_name: git_repository.repo},
             token,
             "Connect your GitHub account to Semaphore to change the repository URL."
           ) do
      update_repository_url_impl(connector, url, token, github_repository)
    else
      {:ok, _permissions} ->
        fail_with(
          :precondition,
          "Write permissions are required on the repository to change the project's repository URL."
        )

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

  defp update_repository_url_impl(connector, url, target_token, github_repository) do
    Multi.new()
    |> Multi.run(:new_git_repository, fn _, _ ->
      Model.GitRepository.from_github(url)
    end)
    |> Multi.run(:updated_repository, fn _, context ->
      Model.RepositoryQuery.update(
        connector.repository,
        %{
          name: context.new_git_repository.repo,
          owner: context.new_git_repository.owner,
          url: context.new_git_repository.ssh_git_url,
          remote_id: github_repository.id,
          private: github_repository.is_private?,
          connected: true
        },
        returning: true
      )
    end)
    |> then(fn
      multi when github_repository.id == connector.repository.remote_id ->
        multi

      multi ->
        multi
        |> Multi.run(:remove_old_webhook, fn _, _context ->
          connector
          |> remove_webhook()
        end)
        |> Multi.run(:remove_old_deploy_key, fn _, _context ->
          connector
          |> remove_deploy_key()
        end)
        |> Multi.run(:create_new_webhook, fn _, context ->
          context.updated_repository
          |> create_webhook(context.new_git_repository, target_token)
        end)
        |> Multi.run(:create_deploy_key, fn _, context ->
          context.updated_repository
          |> create_deploy_key(context.new_git_repository, target_token)
        end)
    end)
    |> Multi.run(:new_repository, fn _, _context ->
      Model.RepositoryQuery.get_by_id(connector.repository.id)
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      %{connector | repository: context.new_repository, git_repository: context.new_git_repository}
      |> wrap()
    end)
  end

  def remove_deploy_key(connector) do
    Model.DeployKeyQuery.get_by_repository_id(connector.repository.id)
    |> case do
      {:error, _} ->
        wrap(:not_found)

      {:ok, deploy_key} when connector.token == "" ->
        log_warn([
          "no token for #{connector.git_repository.owner}/#{connector.git_repository.repo}, skipping deploy key removal on GitHub"
        ])

        Model.DeployKeyQuery.delete(deploy_key.id)

      {:ok, deploy_key} ->
        GithubClient.remove_deploy_key(
          %{
            repo_owner: connector.git_repository.owner,
            repo_name: connector.git_repository.repo,
            key_id: deploy_key.remote_id
          },
          token: connector.token
        )
        |> unwrap(fn _ ->
          Model.DeployKeyQuery.delete(deploy_key.id)
        end)
    end
  end

  def remove_webhook(%{token: ""} = connector) do
    log_warn([
      "no token for #{connector.git_repository.owner}/#{connector.git_repository.repo}, skipping webhook removal on GitHub"
    ])

    connector.repository
    |> Model.RepositoryQuery.update(%{hook_id: ""})
  end

  def remove_webhook(connector) do
    GithubClient.remove_webhook(
      %{
        repo_owner: connector.git_repository.owner,
        repo_name: connector.git_repository.repo,
        webhook_id: connector.repository.hook_id
      },
      token: connector.token
    )
    |> unwrap(fn _ ->
      connector.repository
      |> Model.RepositoryQuery.update(%{hook_id: ""})
    end)
  end

  def create_webhook(repository, git_repository, token) do
    params = %{
      repo_owner: git_repository.owner,
      repo_name: git_repository.repo,
      url: GithubClient.Webhook.url(repository.project_id),
      events: GithubClient.Webhook.events()
    }

    GithubClient.find_webhook(params, token: token)
    |> unwrap_error(fn _ ->
      {:ok, {secret, secret_enc}} = Model.Repositories.generate_hook_secret(repository)

      params
      |> Map.put(:secret, secret)
      |> GithubClient.create_webhook(token: token)
      |> case do
        {:ok, webhook} ->
          Model.RepositoryQuery.update(repository, %{
            hook_secret_enc: secret_enc
          })
          |> unwrap(fn _ -> wrap(webhook) end)

        error ->
          error
      end
    end)
    |> unwrap(fn webhook ->
      Model.RepositoryQuery.update(repository, %{
        hook_id: webhook.id
      })
    end)
  end

  def create_deploy_key(repository, git_repository, token) do
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
      %{
        public_key: public_key,
        private_key_enc: private_key_enc,
        deployed: true,
        remote_id: remote_key.id,
        project_id: repository.project_id,
        repository_id: repository.id
      }
      |> Model.DeployKeyQuery.insert()
    end)
  end
end
