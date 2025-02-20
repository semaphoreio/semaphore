defmodule RepositoryHub.RepositoryModelFactory do
  import RepositoryHub.Toolkit

  @default_webhook_secret "It's a Secret to Everybody"

  def create_repository(params \\ []) do
    params
    |> default
    |> RepositoryHub.Model.RepositoryQuery.insert()
  end

  def build_repository(params \\ []) do
    params
    |> default
    |> then(fn params ->
      struct(RepositoryHub.Model.Repositories, params)
    end)
  end

  def seed_repositories(common_params \\ []) do
    [
      github_repo(common_params),
      githubapp_repo(common_params),
      bitbucket_repo(common_params),
      gitlab_repo(common_params)
    ]
  end

  def bitbucket_repo(params \\ []) do
    with_defaults([integration_type: "bitbucket", provider: "bitbucket"], params)
    |> create_repository()
    |> unwrap!
  end

  def gitlab_repo(params \\ []) do
    with_defaults([integration_type: "gitlab", provider: "gitlab"], params)
    |> create_repository()
    |> unwrap!
  end

  def githubapp_repo(params \\ []) do
    with_defaults([integration_type: "github_app"], params)
    |> create_repository()
    |> unwrap!
  end

  def github_repo(params \\ []) do
    with_defaults([integration_type: "github_oauth_token"], params)
    |> create_repository()
    |> unwrap!
  end

  defp default(params) do
    repository_id = Keyword.get(params, :id, Ecto.UUID.generate())

    hook_secret_enc =
      RepositoryHub.Encryptor.encrypt!(RepositoryHub.WebhookSecretEncryptor, @default_webhook_secret, repository_id)

    params
    |> with_defaults(
      id: repository_id,
      project_id: Ecto.UUID.generate(),
      name: "repository",
      owner: "dummy",
      private: true,
      provider: "github",
      integration_type: "github_app",
      url: "http://github.com/dummy/repository.git",
      pipeline_file: ".semaphore/semaphore.yml",
      default_branch: "main",
      hook_id: "123",
      hook_secret_enc: hook_secret_enc
    )
    |> Enum.into(%{})
  end
end
