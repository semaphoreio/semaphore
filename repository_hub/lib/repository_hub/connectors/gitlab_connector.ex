defmodule RepositoryHub.GitlabConnector do
  # credo:disable-for-this-file

  defstruct [:git_repository, :repository, :token]

  alias __MODULE__

  @type t :: %GitlabConnector{}

  alias RepositoryHub.{
    Model,
    Toolkit,
    GitlabClient
  }

  alias Ecto.Multi

  import Toolkit

  @spec setup(Ecto.UUID.t(), String.t()) :: Toolkit.tupled_result(t())
  def setup(repository_id, token) do
    Model.RepositoryQuery.get_by_id(repository_id)
    |> unwrap(fn repository ->
      Model.GitRepository.new(repository.url)
      |> unwrap(fn git_repository ->
        %GitlabConnector{
          repository: repository,
          git_repository: git_repository,
          token: token
        }
        |> wrap
      end)
    end)
  end

  def update_repository_url(connector, url, organization_name) do
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

          false ->
            connector
            |> can_change_url?(url)
            |> update_repository_url_impl(url, organization_name)
        end)
    end)
  end

  defp can_change_url?(connector, url) do
    Model.GitRepository.new(url)
    |> unwrap(fn git_repository ->
      GitlabClient.find_repository(
        %{
          repo_owner: git_repository.owner,
          repo_name: git_repository.repo
        },
        token: connector.token
      )
    end)
    |> unwrap(fn
      %{with_admin_access?: true} ->
        wrap(connector)

      _ ->
        fail_with(:precondition, "Admin permissions are required on the repository to add the project to Semaphore")
    end)
  end

  defp update_repository_url_impl(connector, url, organization_name) do
    connector
    |> unwrap(fn connector ->
      Multi.new()
      |> Multi.run(:new_git_repository, fn _, _ ->
        Model.GitRepository.new(url)
      end)
      |> Multi.run(:updated_repository, fn _, context ->
        Model.RepositoryQuery.update(
          connector.repository,
          %{
            name: context.new_git_repository.repo,
            owner: context.new_git_repository.owner,
            url: context.new_git_repository.ssh_git_url
          },
          returning: true
        )
      end)
      |> Multi.run(:remove_old_webhook, fn _, _context ->
        connector
        |> remove_webhook()
      end)
      |> Multi.run(:remove_old_deploy_key, fn _, _context ->
        connector
        |> remove_deploy_key()
      end)
      |> Multi.run(:create_new_deploy_key, fn _, context ->
        create_deploy_key(context.updated_repository, context.new_git_repository, connector.token)
      end)
      |> Multi.run(:create_new_webhook, fn _, context ->
        create_webhook(context.updated_repository, context.new_git_repository, connector.token, organization_name)
      end)
      |> RepositoryHub.Repo.transaction()
      |> unwrap(fn context ->
        %{connector | repository: context.updated_repository, git_repository: context.new_git_repository}
        |> wrap
      end)
    end)
  end

  def create_webhook(repository, git_repository, token, organization_name) do
    params = %{
      repo_owner: git_repository.owner,
      repo_name: git_repository.repo,
      url: GitlabClient.Webhook.url(organization_name, repository.id),
      events: GitlabClient.Webhook.events()
    }

    GitlabClient.find_webhook(params, token: token)
    |> unwrap_error(fn _ ->
      {:ok, {secret, secret_enc}} = Model.Repositories.generate_hook_secret(repository)

      params
      |> Map.put(:secret, secret)
      |> GitlabClient.create_webhook(token: token)
      |> case do
        {:ok, _} ->
          Model.RepositoryQuery.update(repository, %{
            hook_secret_enc: secret_enc
          })

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

    GitlabClient.create_deploy_key(
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

  def remove_webhook(connector) do
    params = %{
      repo_owner: connector.git_repository.owner,
      repo_name: connector.git_repository.repo
    }

    GitlabClient.remove_webhook(params, token: connector.token)
    |> wrap()
  end

  def remove_deploy_key(connector) do
    params = %{
      repo_owner: connector.git_repository.owner,
      repo_name: connector.git_repository.repo,
      title: "Semaphore CI"
    }

    GitlabClient.remove_deploy_key(params, token: connector.token)
    |> wrap()
  end
end
