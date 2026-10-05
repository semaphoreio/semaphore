defmodule RepositoryHub.Server.Git.DescribeRevisionActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.GitCliClient
  alias RepositoryHub.Server.DescribeRevisionAction
  alias RepositoryHub.{DeployKeysModelFactory, InternalApiFactory, RepositoryModelFactory}
  alias InternalApi.Repository.{DescribeRevisionRequest, DescribeRevisionResponse, Revision}

  import Mock

  @url "ssh://git@git.example.com/acme/app.git"
  @sha "0123456789abcdef0123456789abcdef01234567"

  setup do
    repository = RepositoryModelFactory.git_repo(provider: "git", url: @url)

    {:ok, _} =
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

    %{adapter: Adapters.git(), repository: repository}
  end

  describe "Git DescribeRevisionAction" do
    test "resolves a reference and describes its commit", %{adapter: adapter, repository: repository} do
      with_mock GitCliClient,
        get_reference: fn %{url: @url, reference: "refs/heads/main"}, opts ->
          assert opts[:private_key] =~ "BEGIN OPENSSH PRIVATE KEY"
          {:ok, %{type: "branch", reference: "refs/heads/main", sha: @sha}}
        end,
        get_commit: fn %{url: @url, revision: @sha}, _opts ->
          {:ok, %{sha: @sha, message: "Fix the thing", author_name: "Ada", author_email: "ada@example.com"}}
        end do
        request = request(repository, reference: "refs/heads/main", commit_sha: "")

        assert {:ok, %DescribeRevisionResponse{commit: commit}} = DescribeRevisionAction.execute(adapter, request)

        assert commit.sha == @sha
        assert commit.msg == "Fix the thing"
        assert commit.author_name == "Ada"
        assert commit.author_uuid == ""
        assert commit.author_avatar_url == ""
      end
    end

    test "describes a pinned commit without resolving the reference", %{adapter: adapter, repository: repository} do
      with_mock GitCliClient,
        get_reference: fn _, _ -> flunk("the reference must not be resolved when a sha is given") end,
        get_commit: fn %{url: @url, revision: @sha}, _opts ->
          {:ok, %{sha: @sha, message: "Pinned", author_name: "Ada", author_email: "ada@example.com"}}
        end do
        request = request(repository, reference: "refs/heads/main", commit_sha: @sha)

        assert {:ok, %DescribeRevisionResponse{commit: commit}} = DescribeRevisionAction.execute(adapter, request)
        assert commit.sha == @sha
        assert commit.msg == "Pinned"
      end
    end

    test "answers with the sha alone when the commit cannot be fetched", %{adapter: adapter, repository: repository} do
      with_mock GitCliClient,
        get_reference: fn _, _ -> {:ok, %{type: "tag", reference: "refs/tags/v1", sha: @sha}} end,
        get_commit: fn _, _ -> {:error, %{status: GRPC.Status.not_found(), message: "server refused"}} end do
        request = request(repository, reference: "refs/tags/v1", commit_sha: "")

        assert {:ok, %DescribeRevisionResponse{commit: commit}} = DescribeRevisionAction.execute(adapter, request)
        assert commit.sha == @sha
        assert commit.msg == ""
        assert commit.author_name == ""
      end
    end

    test "fails when the reference does not exist", %{adapter: adapter, repository: repository} do
      not_found = GRPC.Status.not_found()

      with_mock GitCliClient,
        get_reference: fn _, _ -> {:error, %{status: not_found, message: "Reference 'refs/heads/nope' not found."}} end,
        get_commit: fn _, _ -> flunk("nothing to fetch for an unknown reference") end do
        request = request(repository, reference: "refs/heads/nope", commit_sha: "")

        assert {:error, %{status: ^not_found}} = DescribeRevisionAction.execute(adapter, request)
      end
    end

    test "fails when a pinned commit does not exist", %{adapter: adapter, repository: repository} do
      not_found = GRPC.Status.not_found()

      with_mock GitCliClient,
        get_reference: fn _, _ -> flunk("the reference must not be resolved when a sha is given") end,
        get_commit: fn _, _ -> {:error, %{status: not_found, message: "Unable to fetch revision"}} end do
        request = request(repository, reference: "refs/heads/main", commit_sha: @sha)

        assert {:error, %{status: ^not_found}} = DescribeRevisionAction.execute(adapter, request)
      end
    end

    test "fails when the repository has no deploy key", %{adapter: adapter} do
      repository = RepositoryModelFactory.git_repo(provider: "git", url: @url)
      failed_precondition = GRPC.Status.failed_precondition()

      with_mock GitCliClient,
        get_reference: fn _, _ -> flunk("no git command may run without a deploy key") end,
        get_commit: fn _, _ -> flunk("no git command may run without a deploy key") end do
        request = request(repository, reference: "refs/heads/main", commit_sha: "")

        assert {:error, %{status: ^failed_precondition, message: message}} =
                 DescribeRevisionAction.execute(adapter, request)

        assert message =~ "Deploy key"
      end
    end

    test "fails with an unknown repository id", %{adapter: adapter} do
      request =
        InternalApiFactory.describe_revision_request(
          repository_id: Ecto.UUID.generate(),
          revision: %Revision{reference: "refs/heads/main", commit_sha: ""}
        )

      assert {:error, _} = DescribeRevisionAction.execute(adapter, request)
    end

    test "validates the request", %{adapter: adapter, repository: repository} do
      assert {:error, _} = DescribeRevisionAction.validate(adapter, %DescribeRevisionRequest{})

      assert {:ok, _} =
               DescribeRevisionAction.validate(
                 adapter,
                 request(repository, reference: "refs/heads/main", commit_sha: "")
               )

      assert {:ok, _} = DescribeRevisionAction.validate(adapter, request(repository, reference: "", commit_sha: @sha))

      assert {:error, _} = DescribeRevisionAction.validate(adapter, request(repository, reference: "", commit_sha: ""))

      assert {:error, _} =
               DescribeRevisionAction.validate(
                 adapter,
                 request(repository, reference: "refs/heads/main", commit_sha: "not-a-sha")
               )

      assert {:error, _} =
               DescribeRevisionAction.validate(
                 adapter,
                 request(repository, reference: "refs/heads/main", commit_sha: "")
                 |> Map.put(:repository_id, "not-a-uuid")
               )
    end
  end

  defp request(repository, revision) do
    InternalApiFactory.describe_revision_request(
      repository_id: repository.id,
      revision: struct(Revision, revision)
    )
  end
end
