defmodule HooksReceiver.RepositoryClientTest do
  use ExUnit.Case

  alias HooksReceiver.RepositoryClient, as: RC
  alias InternalApi.Repository.DescribeResponse

  test ".describe formats response" do
    GRPC.Server.start(RepositoryMock, 50_051)

    RepositoryMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      %DescribeResponse{repository: %{id: req.repository_id}}
    end)

    repository_id = "6f47b389-458f-4f6a-8a9e-fe445e0c91d3"
    {:ok, repository} = RC.describe(repository_id)

    assert repository.id == repository_id

    GrpcMock.verify!(RepostoryMock)
  end
end
