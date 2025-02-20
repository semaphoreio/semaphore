defmodule RepositoryHub.GithubClientFactory do
  # credo:disable-for-this-file
  @moduledoc """
  """
  alias RepositoryHub.GithubClient
  import RepositoryHub.Toolkit

  def mocks do
    [
      {GithubClient, [:passthrough],
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
         remove_webhook: &remove_webhook_mock/2,
         repository_permissions: &repository_permissions/2,
         get_reference: &get_branch_mock/2,
         get_branch: &get_branch_mock/2,
         get_tag: &get_tag_mock/2,
         get_commit: &get_commit_mock/2
       ]}
    ]
  end

  def find_repository_mock(params, _opts) do
    admin_access = params.repo_name != "not_my_repo"
    push_access = true

    %{
      id: "12345",
      with_admin_access?: admin_access,
      permissions: %{"admin" => admin_access, "push" => push_access},
      description: "Some description",
      is_private?: true,
      created_at: DateTime.utc_now(),
      provider: "github",
      owner: params.repo_owner,
      name: params.repo_name,
      full_name: "#{params.repo_owner}/#{params.repo_name}",
      default_branch: "main",
      ssh_url: "git@github.com:#{params.repo_owner}/#{params.repo_name}.git"
    }
    |> wrap()
  end

  def create_build_status_mock(_params, _opts) do
    {:ok, %{}}
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
      id: "#{random_integer()}",
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
      id: "#{random_integer()}",
      url: "example.com/hooks/github?hash_id=#{Ecto.UUID.generate()}"
    }
    |> wrap()
  end

  def remove_webhook_mock(_params, _opts) do
    {:ok, %{}}
  end

  def remove_deploy_key_mock(_params, _opts) do
    {:ok, %{}}
  end

  def repository_permissions(_params, _opts) do
    {:ok, %{"admin" => true, "push" => true}}
  end

  def get_branch_mock(_params, _opts) do
    {:ok, %{type: "branch", sha: "1234567"}}
  end

  def get_tag_mock(_params, _opts) do
    {:ok, %{type: "tag", sha: "1234567"}}
  end

  def get_commit_mock(_params, _opts) do
    {:ok,
     %{
       sha: "1234567",
       message: "Commit message",
       author_name: "johndoe",
       author_uuid: "1234567",
       author_avatar_url: "https://avatars.githubusercontent.com/u/1234567?v=3"
     }}
  end
end
