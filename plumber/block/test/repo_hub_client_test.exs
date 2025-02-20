defmodule Block.RepoHubClient.Test do
  use ExUnit.Case

  alias Util.Proto
  alias Block.RepoHubClient
  alias InternalApi.Repository.{
    DescribeManyResponse,
    GetChangedFilePathsResponse,
    GetFileResponse,
  }

  @url_env_name "INTERNAL_API_URL_REPOSITORY"

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(RepoHubMock)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, port)
    :ok
  end

  # get_repo_id (List call)

  test "when URL is invalid in get_repo_id call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:0")

    project_id = UUID.uuid4()
    assert {:error, message} = RepoHubClient.get_repo_id(project_id)
    assert {:timeout, _time_to_wait} = message
  end

  test "when time-out occures in get_repo_id call => error is returned" do
    project_id = UUID.uuid4()

    RepoHubMock
    |> GrpcMock.expect(:describe_many, fn req, _ ->
      assert req.repository_ids == []
      assert req.project_ids == [project_id]

      :timer.sleep(5_000)
      DescribeManyResponse.new()
    end)

    assert {:error, message} = RepoHubClient.get_repo_id(project_id)
    assert {:timeout, _time_to_wait} = message

    GrpcMock.verify!(RepoHubMock)
  end

  test "when client.get_repo_id is called => gRPC server response is processed correctly" do
    project_id = UUID.uuid4()
    repository_id = UUID.uuid4()

    RepoHubMock
    |> GrpcMock.expect(:describe_many, fn req, _ ->
      assert req.repository_ids == []
      assert req.project_ids == [project_id]

      %{repositories: [%{id: repository_id}]}
      |> Proto.deep_new!(DescribeManyResponse)
    end)
    |> GrpcMock.expect(:describe_many, fn req, _ ->
      assert req.repository_ids == []
      assert req.project_ids == [project_id]

      %{repositories: []}
      |> Proto.deep_new!(DescribeManyResponse)
    end)

    assert {:ok, repo_id} =  RepoHubClient.get_repo_id(project_id)
    assert repo_id == repository_id

    assert {:error, message} =  RepoHubClient.get_repo_id(project_id)
    assert message == "There are no repositories for project #{project_id}"

    GrpcMock.verify!(RepoHubMock)
  end

  # get_changes (GetChangedFilePaths call)

  test "when URL is invalid in get_changes call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:0")

    assert {:error, message} = RepoHubClient.get_changes(%{})
    assert {:timeout, _time_to_wait} = message
  end

  test "when time-out occures in get_changes call => error is returned" do
    RepoHubMock
    |> GrpcMock.expect(:get_changed_file_paths, fn _req, _ ->
        :timer.sleep(5_000)
        GetChangedFilePathsResponse.new()
      end)

    assert {:error, message} = RepoHubClient.get_changes(%{})
    assert {:timeout, _time_to_wait} = message

    GrpcMock.verify!(RepoHubMock)
  end

  test "when client.get_changes is called => gRPC server response is processed correctly" do
    RepoHubMock
    |> GrpcMock.expect(:get_changed_file_paths, fn req, _ ->
        %{changed_file_paths: ["#{req.head_rev.reference}", "#{req.comparison_type}"]}
        |> Proto.deep_new!(GetChangedFilePathsResponse)
      end)
    |> GrpcMock.expect(:get_changed_file_paths, fn req, _ ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "The repository '#{req.repository_id}' is not found."
      end)

    params = %{head_rev: %{reference: "ref_1"}, comparison_type: :HEAD_TO_HEAD,
               repository_id: "repo_1"}
    assert {:ok, changes} =  RepoHubClient.get_changes(params)
    assert changes == ["ref_1", "1"]

    assert {:error, message} =  RepoHubClient.get_changes(params)
    assert message == "The repository 'repo_1' is not found."

    GrpcMock.verify!(RepoHubMock)
  end

  # get_file (GetFile call)

  test "when URL is invalid in get_file call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:0")

    assert {:error, message} = RepoHubClient.get_file("repo_1", "sha_1", "/semaphore.yml")
    assert {:timeout, _time_to_wait} = message
  end

  test "when time-out occures in get_file call => error is returned" do
    RepoHubMock
    |> GrpcMock.expect(:get_file, fn _req, _ ->
        :timer.sleep(10_000)
        GetFileResponse.new()
      end)

    assert {:error, message} = RepoHubClient.get_file("repo_1", "sha_1", "/semaphore.yml")
    assert {:timeout, _time_to_wait} = message

    GrpcMock.verify!(RepoHubMock)
  end

  test "when client.get_file is called => gRPC server response is processed correctly" do
    RepoHubMock
    |> GrpcMock.expect(:get_file, fn _req, _ ->
        %{file: %{content: "Rmlyc3QgbGluZS4KU2Vjb25kIGxpbmUuCg=="}}
        |> Proto.deep_new!(GetFileResponse)
      end)
    |> GrpcMock.expect(:get_file, fn req, _ ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "The file '#{req.path}' is not found."
      end)

    assert {:ok, content} =  RepoHubClient.get_file("repo_1", "sha_1", "/semaphore.yml")
    assert content == "First line.\nSecond line.\n"

    assert {:error, {:malformed, message}}
        = RepoHubClient.get_file("repo_1", "sha_1", "/semaphore.yml")
    assert message == "The file '/semaphore.yml' is not found."

    GrpcMock.verify!(RepoHubMock)
  end
end
