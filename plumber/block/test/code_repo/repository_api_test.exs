defmodule Block.CodeRepo.RepositoryAPI.Test do
  use ExUnit.Case
  doctest Block.CodeRepo.RepositoryAPI

  alias Util.Proto
  alias Block.CodeRepo.RepositoryAPI
  alias InternalApi.Repository.{
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

  test "get success answer from API - respond properly" do
    RepoHubMock
    |> GrpcMock.expect(:get_file, fn req, _ ->
        %{file: %{content: "ZmlsZSBjb250ZW50"}}
        |> Proto.deep_new!(GetFileResponse)
      end)
    |> GrpcMock.expect(:get_file, fn req, _ ->
        %{file: %{content: "foo"}}
        |> Proto.deep_new!(GetFileResponse)
      end)
    |> GrpcMock.expect(:get_file, fn req, _ ->
        raise GRPC.RPCError,
          status: :not_found,
          message: "The file '#{req.path}' is not found."
      end)

    assert {:ok, content} = RepositoryAPI.get_file("repo_1", "sha_1", "/semaphore.yml")
    assert content == "file content"

    assert {:error, {:malformed, {msg, message}}}
      = RepositoryAPI.get_file("repo_1", "sha_1", "/semaphore.yml")
    assert msg == "File '/semaphore.yml' is not available"
    assert message == "Invalid content encoding."

    assert {:error, {:malformed, {msg, message}}}
      = RepositoryAPI.get_file("repo_1", "sha_1", "/semaphore.yml")
    assert msg == "File '/semaphore.yml' is not available"
    assert message == "The file '/semaphore.yml' is not found."

    GrpcMock.verify!(RepoHubMock)
  end
end
