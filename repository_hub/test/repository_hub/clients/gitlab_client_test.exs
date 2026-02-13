defmodule RepositoryHub.GitlabClientTest do
  use RepositoryHub.Case, async: false

  alias RepositoryHub.GitlabClient

  import Mock

  describe "GitlabClient" do
    test "find_repository" do
      with_mock(HTTPoison, [],
        get: fn _url, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 200,
            body:
              Jason.encode!(%{
                "permissions" => %{
                  "project_access" => %{"access_level" => 50}
                },
                "visibility" => "private",
                "description" => "Test repo",
                "created_at" => "2024-01-28T10:00:00Z",
                "ssh_url_to_repo" => "git@gitlab.com:owner/repo.git",
                "path" => "repo",
                "path_with_namespace" => "owner/repo",
                "default_branch" => "main",
                "id" => 123
              }),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo"
        }

        assert {:ok, result} = GitlabClient.find_repository(params, token: "token")
        assert result.with_admin_access? == true
        assert result.is_private? == true
        assert result.description == "Test repo"
        assert %DateTime{} = result.created_at
        assert result.provider == "gitlab"
        assert result.id == "123"
        assert result.name == "repo"
        assert result.full_name == "owner/repo"
        assert result.default_branch == "main"
        assert result.url == "git@gitlab.com:owner/repo.git"
      end
    end

    test "find_repository with subgroup path" do
      with_mock(HTTPoison, [],
        get: fn url, _headers, _opts ->
          assert url == "https://gitlab.com/api/v4/projects/testorg%2Ftestgroup%2Ftestrepo"

          response = %HTTPoison.Response{
            status_code: 200,
            body:
              Jason.encode!(%{
                "permissions" => %{
                  "project_access" => %{"access_level" => 50}
                },
                "visibility" => "private",
                "description" => "Subgroup repo",
                "created_at" => "2024-01-28T10:00:00Z",
                "ssh_url_to_repo" => "git@gitlab.com:testorg/testgroup/testrepo.git",
                "path" => "testrepo",
                "path_with_namespace" => "testorg/testgroup/testrepo",
                "default_branch" => "main",
                "id" => 321
              }),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "testorg/testgroup",
          repo_name: "testrepo"
        }

        assert {:ok, result} = GitlabClient.find_repository(params, token: "token")
        assert result.id == "321"
        assert result.full_name == "testorg/testgroup/testrepo"
        assert result.url == "git@gitlab.com:testorg/testgroup/testrepo.git"
      end
    end

    test "create_build_status" do
      with_mock(HTTPoison, [],
        post: fn _url, _body, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 201,
            body: Jason.encode!(%{"id" => 1}),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo",
          commit_sha: "abc123",
          state: "success",
          url: "https://example.com",
          description: "Build successful",
          context: "ci/semaphore"
        }

        assert {:ok, _result} = GitlabClient.create_build_status(params, token: "token")
      end
    end

    test "list_repository_collaborators" do
      next_page_url = "http://url.example?page=2"

      with_mock(HTTPoison, [],
        get: fn _url, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 200,
            body:
              Jason.encode!([
                %{
                  "id" => 1,
                  "username" => "user1",
                  "name" => "User One",
                  "access_level" => 40
                }
              ]),
            headers: [{"link", "<#{next_page_url}>; rel=\"next\""}]
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo",
          page_token: ""
        }

        assert {:ok, result} = GitlabClient.list_repository_collaborators(params, token: "token")
        assert is_list(result.items)
        assert length(result.items) == 1
        assert result.next_page_token == Base.encode64(next_page_url)
      end
    end

    test "get_file" do
      with_mock(HTTPoison, [],
        get: fn _url, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 200,
            body:
              Jason.encode!(%{
                "content" => Base.encode64("file content"),
                "encoding" => "base64"
              }),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo",
          commit_sha: "main",
          path: "test.txt"
        }

        assert {:ok, content} = GitlabClient.get_file(params, token: "token")
        assert content == "file content" |> Base.encode64()
      end
    end

    test "get_branch" do
      with_mock(HTTPoison, [],
        get: fn _url, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 200,
            body:
              Jason.encode!(%{
                "name" => "main",
                "commit" => %{
                  "id" => "abc123"
                }
              }),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo",
          branch_name: "main"
        }

        assert {:ok, result} = GitlabClient.get_branch(params, token: "token")
        assert result.sha == "abc123"
        assert result.type == "branch"
      end
    end

    test "get_tag" do
      with_mock(HTTPoison, [],
        get: fn _url, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 200,
            body:
              Jason.encode!(%{
                "name" => "v1.0.0",
                "commit" => %{
                  "id" => "abc123"
                }
              }),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo",
          tag_name: "v1.0.0"
        }

        assert {:ok, result} = GitlabClient.get_tag(params, token: "token")
        assert result.sha == "abc123"
        assert result.type == "tag"
      end
    end

    test "get_reference with branch" do
      with_mock(HTTPoison, [],
        get: fn _url, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 200,
            body:
              Jason.encode!(%{
                "name" => "main",
                "commit" => %{
                  "id" => "abc123"
                }
              }),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo",
          reference: "refs/heads/main"
        }

        assert {:ok, result} = GitlabClient.get_reference(params, token: "token")
        assert result.sha == "abc123"
        assert result.type == "branch"
      end
    end

    test "create_deploy_key" do
      with_mock(HTTPoison, [],
        post: fn _url, _body, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 201,
            body:
              Jason.encode!(%{
                "id" => 1,
                "title" => "deploy-key-1",
                "key" => "ssh-rsa AAAAB..."
              }),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo",
          title: "deploy-key-1",
          key: "ssh-rsa AAAAB...",
          read_only: true
        }

        assert {:ok, result} = GitlabClient.create_deploy_key(params, token: "token")
        assert result.id == "1"
      end
    end

    test "create_webhook" do
      with_mock(HTTPoison, [],
        post: fn _url, _body, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 201,
            body:
              Jason.encode!(%{
                "id" => 1,
                "url" => "https://example.com/webhook"
              }),
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = %{
          repo_owner: "owner",
          repo_name: "repo",
          name: "example-webhook",
          url: "https://example.com/webhook",
          events: GitlabClient.Webhook.events(),
          secret: "webhook-secret"
        }

        assert {:ok, result} = GitlabClient.create_webhook(params, token: "token")
        assert result.id == "1"
      end
    end
  end
end
