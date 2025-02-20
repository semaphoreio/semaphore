defmodule Block.CodeRepo.Test do
  use ExUnit.Case
  doctest Block.CodeRepo

  alias Block.CodeRepo
  alias Util.Proto
  alias InternalApi.Repository.{GetFileResponse, DescribeManyResponse}

  @test_commit_sha_1 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"
  @test_commit_sha_2 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"

  @repository_url_env_name "INTERNAL_API_URL_REPOSITORY"

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")
    :ok
  end

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(RepoHubMock)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url(@repository_url_env_name, port)
    :ok
  end

  test "no service type" do
    assert {:error, _} = CodeRepo.get_file(%{})
  end

  test "wrong service type" do
    assert {:error, _} = CodeRepo.get_file(%{"service" => "foo"})
  end

  test "missing repo name" do
    assert {:error, _} = CodeRepo.get_file(%{"service" => "local"})
  end

  test "wrong local repo name" do
    args = %{
      "service" => "local",
      "repo_name" => "non-existing",
      "working_dir" => ".semaphore", "file_name" => "semaphore.yml"
    }
    assert {:error, _} =  CodeRepo.get_file(args)
  end

  test "fetch repository_id from RepositoryHub if it's missing in payload" do
    repository_id = UUID.uuid4()
    project_id = UUID.uuid4()
    RepoHubMock
    |> GrpcMock.expect(:describe_many, fn req, _ ->
      assert req.repository_ids == []
      assert req.project_ids == [project_id]

      %{repositories: [%{id: repository_id}]}
      |> Proto.deep_new!(DescribeManyResponse)
    end)
    |> GrpcMock.expect(:get_file, fn req, _ ->

      assert req.repository_id == repository_id
      assert req.path == ".semaphore/semaphore.yml"
      assert req.commit_sha == @test_commit_sha_1

      %{file: %{content: "dmVyc2lvbg=="}}
      |> Proto.deep_new!(GetFileResponse)
    end)

    branch_data = %{"owner" => "renderedtext",
                    "repo_name" => "front",
                    "commit_sha" => @test_commit_sha_1,
                    "file_name" => "semaphore.yml",
                    "working_dir" => ".semaphore",
                    "project_id" => project_id,
                    "repository_id" => ""}
    opts = Map.merge(args(), branch_data)
    assert {:ok, content} = CodeRepo.get_file(opts)
    assert String.contains?(content, "version")

    GrpcMock.verify!(RepoHubMock)
  end

  test "use RepositoryHub to get files" do
    repository_id = UUID.uuid4()
    RepoHubMock
    |> GrpcMock.expect(:get_file, fn req, _ ->

      assert req.repository_id == repository_id
      assert req.path == ".semaphore/semaphore.yml"
      assert req.commit_sha == @test_commit_sha_1

      %{file: %{content: "dmVyc2lvbg=="}}
      |> Proto.deep_new!(GetFileResponse)
    end)

    branch_data = %{"owner" => "renderedtext",
                    "repo_name" => "front",
                    "commit_sha" => @test_commit_sha_1,
                    "file_name" => "semaphore.yml",
                    "working_dir" => ".semaphore",
                    "project_id" => UUID.uuid4(),
                    "repository_id" => repository_id}
    opts = Map.merge(args(), branch_data)
    assert {:ok, content} = CodeRepo.get_file(opts)
    assert String.contains?(content, "version")

    GrpcMock.verify!(RepoHubMock)
  end

  test "working_dir is prepended to file name and file is fetched from RepositoryHub" do
    repository_id = UUID.uuid4()
    RepoHubMock
    |> GrpcMock.expect(:get_file, fn req, _ ->
      assert req.repository_id == repository_id
      assert req.path == "foo/bar/baz/file_a.yaml"
      assert req.commit_sha == @test_commit_sha_2

        %{file: %{content: "dmVyc2lvbg=="}}
        |> Proto.deep_new!(GetFileResponse)
      end)

    opts =
      %{"file_name" => "file_a.yaml", "working_dir" => "foo/bar/baz",
        "project_id" => UUID.uuid4(),
        "repository_id" => repository_id}
      |> Map.merge(wk_dir_args())

    assert {:ok, content} = CodeRepo.get_file(opts)
    assert String.contains?(content, "version")

    GrpcMock.verify!(RepoHubMock)
  end

  test "when working_dir is `/` file is fetched from RepositoryHub" do
    repository_id = UUID.uuid4()
    RepoHubMock
    |> GrpcMock.expect(:get_file, fn req, _ ->

      assert req.repository_id == repository_id
      assert req.path == "/semaphore.yml"
      assert req.commit_sha == @test_commit_sha_2

        %{file: %{content: "dmVyc2lvbg=="}}
        |> Proto.deep_new!(GetFileResponse)
      end)

    opts =
      %{"file_name" => "semaphore.yml", "working_dir" => "/",
        "project_id" => UUID.uuid4(),
        "repository_id" => repository_id}
      |> Map.merge(wk_dir_args())

    assert {:ok, content} = CodeRepo.get_file(opts)
    assert String.contains?(content, "version")

    GrpcMock.verify!(RepoHubMock)
  end

  defp args do
    %{
      "service"       => "git_hub",
      "owner"         => "renderedtext",
      "repo_name"     => "pipelines-test-repo-auto-call",
    }
  end

  defp wk_dir_args() do
    %{
     "branch_name" => "working_dir_test",
     "commit_sha" => @test_commit_sha_2
    }
    |> Map.merge(args())
  end
end
