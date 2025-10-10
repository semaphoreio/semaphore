defmodule RepositoryHub.BitbucketClientFactory do
  # credo:disable-for-this-file
  @moduledoc """
  Factory providing mocks for `RepositoryHub.BitbucketClient`
  """
  alias RepositoryHub.{BitbucketClient, Toolkit}
  import Toolkit

  def mocks do
    [
      {BitbucketClient, [:passthrough],
       [
         find_repository: &find_repository_mock/2,
         create_build_status: &create_build_status_mock/2,
         list_repository_collaborators: &list_repository_collaborators_mock/2,
         list_repositories: &list_repositories_mock/2,
         get_file: &get_file_mock/2,
         find_deploy_key: &find_deploy_key_mock/2,
         create_deploy_key: &create_deploy_key_mock/2,
         remove_deploy_key: &remove_deploy_key_mock/2,
         create_webhook: &create_webhook_mock/2,
         remove_webhook: &remove_webhook_mock/2
       ]},
      {RepositoryHub.UserClient, [:passthrough],
       [
         describe: fn user_id ->
           {:ok,
            %{
              user_id: user_id,
              user: %{creation_source: :NOT_SET}
            }}
         end,
         get_repository_token: fn _integration_type, _user_id ->
           {:ok, "mock-bitbucket-token"}
         end
       ]}
    ]
  end

  def find_repository_mock(params, _opts) do
    admin_access = params.repo_name != "not_my_repo"

    %{
      uuid: "{c8a0cc40-2b34-4d54-98c0-0f115233b9fa}",
      with_admin_access?: admin_access,
      description: "Some description",
      is_private?: true,
      created_at: DateTime.utc_now(),
      provider: "github"
    }
    |> wrap()
  end

  def list_repository_collaborators_mock(_params, _opts) do
  end

  def list_repositories_mock(_params, _opts) do
  end

  def get_file_mock(_params, _opts) do
  end

  def find_deploy_key_mock(params, _opts) do
    %{
      id: params.key_id,
      title: "semaphore-some-key",
      key: "somekey",
      read_only: true
    }
    |> wrap()
  end

  def create_deploy_key_mock(_params, _opts) do
    %{
      id: random_integer(),
      title: "semaphore-some-key",
      key: "somekey",
      read_only: true
    }
    |> wrap()
  end

  def create_webhook_mock(%{repo_name: "failed"}, _opts) do
    %{
      status: GRPC.Status.failed_precondition(),
      message: "Error"
    }
    |> error()
  end

  def create_webhook_mock(_params, _opts) do
    %{
      id: random_integer(),
      url: "example.com/hooks/github?hash_id=#{Ecto.UUID.generate()}"
    }
    |> wrap
  end

  def remove_webhook_mock(_params, _opts) do
    {:ok, %{}}
  end

  def remove_deploy_key_mock(_params, _opts) do
    {:ok, %{}}
  end

  def create_build_status_mock(_, _) do
    %Google.Protobuf.Empty{}
    |> wrap()
  end

  @spec build_status_params(Keyword.t()) :: RepositoryHub.BitbucketClient.create_build_status_params()
  def build_status_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      commit_sha: Base.encode16(Ecto.UUID.generate()),
      status: "SUCCESSFUL",
      url: "https://bitbucket.org/dummy/repository",
      description: "Some description",
      context: "Some context"
    )
    |> Enum.into(%{})
  end

  @spec list_repository_collaborators_params(Keyword.t()) ::
          RepositoryHub.BitbucketClient.list_repository_collaborators_params()
  def list_repository_collaborators_params(params \\ []) do
    page_token = Keyword.get(params, :page_token, Base.encode64("https://some-encoded-url.example.com"))

    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      page_token: page_token
    )
    |> Enum.into(%{})
  end

  @spec list_repositories_params(Keyword.t()) :: RepositoryHub.BitbucketClient.list_repositories_params()
  def list_repositories_params(params \\ []) do
    page_token = Keyword.get(params, :page_token, Base.encode64("https://some-encoded-url.example.com"))

    params
    |> with_defaults(page_token: page_token, query: "")
    |> Enum.into(%{})
  end

  def build_repository(params \\ []) do
    params =
      params
      |> with_defaults(
        uuid: Ecto.UUID.generate(),
        name: "repository",
        full_name: "repository",
        href: "https://bitbucket.org/dummy/repository"
      )
      |> Enum.into(%{})

    %{
      "uuid" => params.uuid,
      "name" => params.name,
      "full_name" => params.full_name,
      "links" => %{"self" => %{"href" => params.href}}
    }
  end

  @spec get_file_params(Keyword.t()) :: RepositoryHub.BitbucketClient.get_file_params()
  def get_file_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      commit_sha: "1a6f396",
      path: "README.md"
    )
    |> Enum.into(%{})
  end
end
