defmodule RepositoryHub.GitlabClientFactory do
  # credo:disable-for-this-file
  @moduledoc """
  """
  alias RepositoryHub.GitlabClient
  import RepositoryHub.Toolkit

  def mocks do
    [
      {GitlabClient, [:passthrough],
       [
         find_repository: &find_repository_mock/2,
         create_build_status: &create_build_status_mock/2,
         list_repository_collaborators: &list_repository_collaborators_mock/2,
         list_repositories: &list_repositories_mock/2,
         get_reference: &get_reference_mock/2,
         get_branch: &get_branch_mock/2,
         get_tag: &get_tag_mock/2,
         get_file: &get_file_mock/2,
         find_deploy_key: &find_deploy_key_mock/2,
         create_deploy_key: &create_deploy_key_mock/2,
         remove_deploy_key: &remove_deploy_key_mock/2,
         create_webhook: &create_webhook_mock/2,
         remove_webhook: &remove_webhook_mock/2,
         get_commit: &get_commit_mock/2,
         find_webhook: &find_webhook_mock/2,
         find_user: &find_user_mock/2,
         fork: &fork_mock/2
       ]}
    ]
  end

  def find_repository_mock(params, _opts) do
    %{
      id: "12345",
      with_admin_access?: true,
      is_private?: true,
      web_url: "https://gitlab.com/diaspora/diaspora-project-site",
      description: "Sample project",
      created_at: DateTime.utc_now() |> to_string(),
      provider: "gitlab",
      name: "#{params.repo_name}",
      full_name: "#{params.repo_owner}/#{params.repo_name}",
      default_branch: "main"
    }
    |> wrap()
  end

  def create_build_status_mock(_params, _opts) do
    %{
      id: 9876,
      status: "success",
      name: "SemaphoreCI Pipeline",
      target_url: "https://example.com/pipeline/123",
      created_at: DateTime.utc_now() |> to_string()
    }
    |> wrap()
  end

  def list_repository_collaborators_mock(%{repository_id: "empty-repo"}, _opts) do
    %{items: [], next_page_token: ""} |> wrap()
  end

  def list_repository_collaborators_mock(_params, _opts) do
    collaborators = [
      %{
        "id" => 123,
        "username" => "user1",
        "name" => "User One",
        "state" => "active",
        "avatar_url" => "https://gitlab.com/uploads/user/avatar/123/avatar.png",
        "web_url" => "https://gitlab.com/user1",
        "access_level" => 40
      },
      %{
        "id" => 456,
        "username" => "user2",
        "name" => "User Two",
        "state" => "active",
        "avatar_url" => "https://gitlab.com/uploads/user/avatar/456/avatar.png",
        "web_url" => "https://gitlab.com/user2",
        "access_level" => 30
      }
    ]

    %{
      items: collaborators,
      next_page_token: ""
    }
    |> wrap()
  end

  def list_repositories_mock(%{page_token: "empty"}, _opts) do
    {:ok, %{items: [], next_page_token: ""}}
  end

  def list_repositories_mock(_params, _opts) do
    repositories = [
      %{
        "id" => 123,
        "path" => "repository1",
        "description" => "Test repository 1",
        "web_url" => "https://gitlab.com/organization1/repository1",
        "ssh_url_to_repo" => "git@gitlab.com:organization1/repository1.git",
        "path_with_namespace" => "organization1/repository1",
        "permissions" => %{
          "project_access" => %{
            "access_level" => 50
          },
          "group_access" => %{
            "access_level" => 30
          }
        }
      }
    ]

    %{
      items: repositories,
      next_page_token: ""
    }
    |> wrap()
  end

  def get_reference_mock(_params, _opts) do
    %{
      type: "commit",
      sha: "abc123"
    }
    |> wrap()
  end

  def get_branch_mock(_params, _opts) do
    %{
      name: "main",
      commit: %{sha: "abc123"}
    }
    |> wrap()
  end

  def get_tag_mock(_params, _opts) do
    %{
      name: "v1.0",
      commit: %{sha: "def456"}
    }
    |> wrap()
  end

  def get_file_mock(params, _opts) do
    if params.path == "non-existent-file.txt" do
      error(%{
        status: GRPC.Status.not_found(),
        message: "File not found."
      })
    else
      %{
        content: Base.encode64("file content"),
        encoding: "base64",
        size: 12,
        file_name: "README.md",
        file_path: "README.md"
      }
      |> wrap()
    end
  end

  def find_deploy_key_mock(_params, _opts) do
    %{
      id: 54321,
      title: "SemaphoreCI Deploy Key",
      key: "ssh-rsa AAAAB3Nza...",
      created_at: "2024-01-01T00:00:00Z"
    }
    |> wrap()
  end

  def create_deploy_key_mock(_params, _opts) do
    %{
      id: 54321,
      key: "ssh-rsa AAAAB3Nza...",
      title: "SemaphoreCI Deploy Key",
      created_at: DateTime.utc_now() |> to_string(),
      can_push: false
    }
    |> wrap()
  end

  def remove_deploy_key_mock(_params, _opts) do
    {:ok, ""}
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
      id: 112_233 |> Integer.to_string(),
      url: "https://example.com/webhook",
      created_at: DateTime.utc_now() |> to_string(),
      push_events: true
    }
    |> wrap()
  end

  def remove_webhook_mock(_params, _opts) do
    {:ok, ""}
  end

  def get_commit_mock(_params, _opts) do
    %{
      sha: "abc123",
      message: "Initial commit",
      author_name: "Dev User",
      author_email: "dev@example.com"
    }
    |> wrap()
  end

  def find_webhook_mock(%{webhook_id: "nothing"}, _opts), do: error("Webhook does not exist")

  def find_webhook_mock(_params, _opts) do
    %{
      id: 112_233 |> Integer.to_string(),
      url: "https://example.com/webhook",
      created_at: DateTime.utc_now() |> to_string(),
      push_events: true,
      has_secret?: true
    }
    |> wrap()
  end

  def fork_mock(%{repo_name: "failed"}, _opts) do
    %{
      status: GRPC.Status.failed_precondition(),
      message: "Failed to fork repository"
    }
    |> error()
  end

  def fork_mock(params, _opts) do
    %{
      url: "git@gitlab.com:forked-owner/#{params.repo_name}.git",
      web_url: "https://gitlab.com/forked-owner/#{params.repo_name}"
    }
    |> wrap()
  end

  defp find_user_mock(_params, _token) do
    %{
      id: "1234",
      username: "john_doe",
      name: "John Doe",
      avatar_url: "https://gitlab.com/uploads/user/avatar/1234/avatar.png"
    }
    |> wrap()
  end
end
