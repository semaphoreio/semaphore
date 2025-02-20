defmodule RepositoryHub.GithubClientTest do
  use RepositoryHub.Case, async: false
  alias RepositoryHub.{GithubClient, TentacatFactory}

  import Mock
  import RepositoryHub.Toolkit

  setup_with_mocks(TentacatFactory.mocks(), ctx) do
    ctx
  end

  describe "GithubClient" do
    test "find_deploy_key" do
      response =
        find_deploy_key_params()
        |> GithubClient.find_deploy_key(token: "abc")

      assert {:ok, _result} = response
    end

    test "remove_deploy_key" do
      response =
        remove_deploy_key_params()
        |> GithubClient.remove_deploy_key(token: "abc")

      assert {:ok, _result} = response
    end

    test "create_deploy_key" do
      response =
        create_deploy_key_params()
        |> GithubClient.create_deploy_key(token: "abc")

      assert {:ok, _result} = response
    end

    test "create_build_status" do
      response =
        build_status_params()
        |> GithubClient.create_build_status(token: "abc")

      assert {:ok, _result} = response
    end

    test "list_repository_collaborators" do
      response =
        list_repository_collaborators_params()
        |> GithubClient.list_repository_collaborators(token: "foobar")

      assert {:ok, _result} = response
    end

    test "get_file" do
      response =
        get_file_params()
        |> GithubClient.get_file(token: "foobar")

      assert {:ok, _result} = response
    end

    test "list_repositories" do
      response =
        list_repositories_params()
        |> GithubClient.list_repositories(token: "foobar")

      assert {:ok, _result} = response
    end

    test "find_repository" do
      response =
        find_repository_params()
        |> GithubClient.find_repository(token: "foobar")

      assert {:ok, result} = response
      assert %{} = result
    end

    test "create_webhook success" do
      response =
        create_webhook_params()
        |> GithubClient.create_webhook(token: "foobar")

      assert {:ok, result} = response
      assert %{id: _id, url: _url} = result
    end

    test "create_webhook failed" do
      response =
        create_webhook_params(repo_name: "failed")
        |> GithubClient.create_webhook(token: "foobar")

      assert {:error, %{status: status, message: message}} = response
      assert status == GRPC.Status.failed_precondition()

      assert message ==
               "The repository contains too many webhooks. Please remove some before trying again."
    end

    test "get_branch" do
      response =
        get_branch_params()
        |> GithubClient.get_branch(token: "foobar")

      assert {:ok, result} = response
      assert %{type: "branch", sha: _} = result
    end

    test "get_tag" do
      response =
        get_tag_params()
        |> GithubClient.get_tag(token: "foobar")

      assert {:ok, result} = response
      assert %{type: "tag", sha: _} = result
    end

    test "get_tag with missing" do
      response =
        get_tag_params(tag_name: "v1.0.2")
        |> GithubClient.get_tag(token: "foobar")

      assert {:error, %{message: "Tag not found.", status: 5}} = response
    end

    test "get_commit" do
      response =
        get_commit_params()
        |> GithubClient.get_commit(token: "foobar")

      assert {:ok, result} = response

      assert MapSet.new(~w(sha message author_name author_uuid author_avatar_url)a) ==
               MapSet.new(result, &elem(&1, 0))
    end

    test "get_commit with pagination" do
      response =
        get_commit_params(repo_name: "chmura")
        |> GithubClient.get_commit(token: "foobar")

      assert {:ok, result} = response

      assert MapSet.new(~w(sha message author_name author_uuid author_avatar_url)a) ==
               MapSet.new(result, &elem(&1, 0))
    end
  end

  @spec build_status_params(Keyword.t()) :: GithubClient.create_build_status_params()
  defp build_status_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      commit_sha: Base.encode16(Ecto.UUID.generate()),
      status: "SUCCESSFUL",
      url: "",
      description: "",
      context: ""
    )
    |> Enum.into(%{})
  end

  @spec find_repository_params(Keyword.t()) :: GithubClient.find_repository_params()
  defp find_repository_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository"
    )
    |> Enum.into(%{})
  end

  @spec list_repository_collaborators_params(Keyword.t()) ::
          GithubClient.list_repository_collaborators_params()
  defp list_repository_collaborators_params(params \\ []) do
    page_token = Keyword.get(params, :page_token, Base.encode64("https://some-encoded-url.example.com"))

    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      page_token: page_token
    )
    |> Enum.into(%{})
  end

  @spec list_repositories_params(Keyword.t()) :: GithubClient.list_repositories_params()
  defp list_repositories_params(params \\ []) do
    page_token = Keyword.get(params, :page_token, Base.encode64("https://some-encoded-url.example.com"))

    params
    |> with_defaults(page_token: page_token, type: "all")
    |> Enum.into(%{})
  end

  @spec get_file_params(Keyword.t()) :: GithubClient.get_file_params()
  defp get_file_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      commit_sha: "1a6f396",
      path: "README.md"
    )
    |> Enum.into(%{})
  end

  @spec create_webhook_params(Keyword.t()) :: GithubClient.create_webhook_params()
  defp create_webhook_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      url: "https://some-encoded-url.example.com",
      events: ["issue_comment", "member", "pull_request", "push"],
      secret: "supersecret"
    )
    |> Enum.into(%{})
  end

  @spec create_deploy_key_params(Keyword.t()) :: GithubClient.create_deploy_key_params()
  defp create_deploy_key_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      title: "semaphore-dummy-repository",
      read_only: false,
      key: TentacatFactory.ssh_key()
    )
    |> Enum.into(%{})
  end

  @spec find_deploy_key_params(Keyword.t()) :: GithubClient.find_deploy_key_params()
  defp find_deploy_key_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      key_id: 1
    )
    |> Enum.into(%{})
  end

  @spec remove_deploy_key_params(Keyword.t()) :: GithubClient.remove_deploy_key_params()
  defp remove_deploy_key_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      key_id: 1
    )
    |> Enum.into(%{})
  end

  defp get_branch_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      branch_name: "master"
    )
    |> Enum.into(%{})
  end

  defp get_tag_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      tag_name: "v1.0.0"
    )
    |> Enum.into(%{})
  end

  defp get_commit_params(params \\ []) do
    params
    |> with_defaults(
      repo_owner: "dummy",
      repo_name: "repository",
      commit_sha: "48038c4d189536a0862a2c20ed832dc34bd1c8b2"
    )
    |> Enum.into(%{})
  end
end
