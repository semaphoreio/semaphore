defmodule HooksProcessor.Clients.RepositoryClient.Test do
  use ExUnit.Case

  alias InternalApi.Repository.DescribeRevisionResponse
  alias HooksProcessor.Clients.RepositoryClient

  @grpc_port 50_048

  setup_all do
    GRPC.Server.start(RepositoryServiceMock, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(RepositoryServiceMock)

      Test.Helpers.wait_until_stopped(RepositoryServiceMock)
    end)

    {:ok, %{}}
  end

  setup do
    repository = %{
      id: UUID.uuid4()
    }

    revision = %{
      commit_sha: "023becf74ae8a5d93911db4bad7967f94343b44b",
      reference: "refs/head/master"
    }

    {:ok, %{repository: repository, revision: revision}}
  end

  # Describe

  test "describe_revision() correctly timeouts if server takes to long to respond", ctx do
    use_mock_repository_service()

    RepositoryServiceMock
    |> GrpcMock.expect(:describe_revision, fn _req, _ ->
      :timer.sleep(5_500)
      %DescribeRevisionResponse{}
    end)

    assert {:error, error} =
             RepositoryClient.describe_revision(ctx.repository.id, ctx.revision.reference, ctx.revision.commit_sha)

    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = error

    GrpcMock.verify!(RepositoryServiceMock)
  end

  test "describe_revision() returns error when server responds with anything but OK", ctx do
    use_mock_repository_service()

    RepositoryServiceMock
    |> GrpcMock.expect(:describe_revision, fn _req, _ ->
      raise %GRPC.RPCError{message: "Error", status: 2}
    end)

    assert {:error, error} =
             RepositoryClient.describe_revision(ctx.repository.id, ctx.revision.reference, ctx.revision.commit_sha)

    assert error.message == "Error"

    GrpcMock.verify!(RepositoryServiceMock)
  end

  test "valid describe_revision() response from server is processed correctly", ctx do
    use_mock_repository_service()

    RepositoryServiceMock
    |> GrpcMock.expect(:describe_revision, fn req, _ ->
      assert req.repository_id == ctx.repository.id
      assert req.revision.commit_sha == ctx.revision.commit_sha
      assert req.revision.reference == ctx.revision.reference

      %DescribeRevisionResponse{
        commit: %{
          sha: "commit_sha",
          msg: "commit_msg",
          author_name: "nick",
          author_uuid: "123",
          author_avatar_url: "avatar_url"
        }
      }
    end)

    assert {:ok, commit} =
             RepositoryClient.describe_revision(ctx.repository.id, ctx.revision.reference, ctx.revision.commit_sha)

    assert commit.sha == "commit_sha"
    assert commit.msg == "commit_msg"
    assert commit.author_name == "nick"
    assert commit.author_uuid == "123"
    assert commit.author_avatar_url == "avatar_url"

    GrpcMock.verify!(RepositoryServiceMock)
  end

  # Utility

  defp use_mock_repository_service,
    do: Application.put_env(:hooks_processor, :repository_grpc_url, "localhost:#{inspect(@grpc_port)}")
end
