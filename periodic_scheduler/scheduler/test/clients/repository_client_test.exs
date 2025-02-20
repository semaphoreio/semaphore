defmodule Scheduler.Clients.RepositoryClient.Test do
  use ExUnit.Case
  alias Scheduler.Clients.RepositoryClient

  @grpc_port 50_064
  setup_all do
    GRPC.Server.start(Test.MockRepositoryService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockRepositoryService)
    end)

    {:ok, %{}}
  end

  test "returns {:ok, commit} when repository service responds with OK" do
    use_mock_repository_service()
    mock_repository_service_response("ok")

    assert {:ok, %InternalApi.Repository.Commit{sha: "1234566", msg: "commit message"}} =
             RepositoryClient.describe_revision("repository_id", %{
               revision: "refs/heads/master",
               commit_sha: ""
             })
  end

  test "returns {:error, timeout} when repository service times out" do
    use_mock_repository_service()
    mock_repository_service_response("timeout")

    assert {:error, status} =
             RepositoryClient.describe_revision("repository_id", %{
               revision: "refs/heads/master",
               commit_sha: ""
             })

    assert status == {:timeout, 10_000}
  end

  test "returns {:error, status} when workflow service responds with anything but OK" do
    use_mock_repository_service()
    mock_repository_service_response("failed_precondition")

    assert {:error, %GRPC.RPCError{status: status, message: "Failed precondition"}} =
             RepositoryClient.describe_revision("repository_id", %{
               revision: "refs/heads/master",
               commit_sha: ""
             })

    assert GRPC.Status.failed_precondition() == status
  end

  defp use_mock_repository_service(),
    do: Application.put_env(:scheduler, :repositoryhub_grpc_endpoint, "localhost:#{@grpc_port}")

  def mock_repository_service_response(value),
    do: Application.put_env(:scheduler, :mock_repository_service_response, value)
end
