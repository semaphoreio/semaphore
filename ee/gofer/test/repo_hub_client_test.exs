defmodule Gofer.RepoHubClient.Test do
  use ExUnit.Case

  alias Util.Proto
  alias Gofer.RepoHubClient

  alias InternalApi.Repository.{
    ListResponse,
    GetChangedFilePathsResponse
  }

  @url_env_name "REPOHUB_GRPC_URL"
  @mock_server_port 51_500

  setup_all do
    # Start the gRPC server
    GRPC.Server.start(RepoHubMock, @mock_server_port)

    on_exit(fn ->
      GRPC.Server.stop(RepoHubMock)
    end)

    :ok
  end

  # get_repo_id (List call)

  test "when URL is invalid in get_repo_id call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:12345")

    assert {:error, message} = RepoHubClient.get_repo_id("project_id_1")
    assert {:timeout, _time_to_wait} = message
  end

  test "when time-out occures in get_repo_id call => error is returned" do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")

    RepoHubMock
    |> GrpcMock.expect(:list, fn _req, _ ->
      :timer.sleep(5_000)
      ListResponse.new()
    end)

    assert {:error, message} = RepoHubClient.get_repo_id("project_id_1")
    assert {:timeout, _time_to_wait} = message

    GrpcMock.verify!(RepoHubMock)
  end

  test "when client.get_repo_id is called => gRPC server response is processed correctly" do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")

    RepoHubMock
    |> GrpcMock.expect(:list, fn req, _ ->
      %{repositories: [%{id: req.project_id}]}
      |> Proto.deep_new!(ListResponse)
    end)
    |> GrpcMock.expect(:list, fn req, _ ->
      raise GRPC.RPCError,
        status: :not_found,
        message: "The repositories for project '#{req.project_id}' are not found."
    end)

    assert {:ok, repo_id} = RepoHubClient.get_repo_id("project_id_1")
    assert repo_id == "project_id_1"

    assert {:error, message} = RepoHubClient.get_repo_id("project_id_1")
    assert message == "The repositories for project 'project_id_1' are not found."

    GrpcMock.verify!(RepoHubMock)
  end

  # get_changes (GetChangedFilePaths call)

  test "when URL is invalid in get_changes call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:12345")

    assert {:error, message} = RepoHubClient.get_changes(%{})
    assert :timeout == message
  end

  test "when time-out occures in get_changes call => error is returned" do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")

    RepoHubMock
    |> GrpcMock.expect(:get_changed_file_paths, fn _req, _ ->
      :timer.sleep(10_000)
      GetChangedFilePathsResponse.new()
    end)

    assert {:error, message} = RepoHubClient.get_changes(%{})
    assert {:timeout, _time_to_wait} = message

    GrpcMock.verify!(RepoHubMock)
  end

  test "when client.get_changes is called => gRPC server response is processed correctly" do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")

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

    params = %{
      head_rev: %{reference: "ref_1"},
      comparison_type: :HEAD_TO_HEAD,
      repository_id: "repo_1"
    }

    assert {:ok, changes} = RepoHubClient.get_changes(params)
    assert changes == ["ref_1", "HEAD_TO_HEAD"]

    assert {:error, message} = RepoHubClient.get_changes(params)
    assert message == "The repository 'repo_1' is not found."

    GrpcMock.verify!(RepoHubMock)
  end
end
