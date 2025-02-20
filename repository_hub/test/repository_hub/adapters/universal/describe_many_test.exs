defmodule RepositoryHub.Server.DescribeManyActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.RepositoryModelFactory
  alias InternalApi.Repository.RepositoryService.Stub

  setup do
    project_id = Ecto.UUID.generate()
    RepositoryModelFactory.seed_repositories(project_id: project_id)
    RepositoryModelFactory.seed_repositories(project_id: Ecto.UUID.generate())

    %{project_id: project_id}
  end

  describe "Universal DescribeManyAction" do
    test "should return a DescribeMany of repositories", %{project_id: project_id} do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      request = %InternalApi.Repository.DescribeManyRequest{project_ids: [project_id]}
      {:ok, response} = Stub.describe_many(channel, request)

      assert length(response.repositories) == 4
    end

    test "should return a list of empty repositories for project with no repositories" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      request = %InternalApi.Repository.DescribeManyRequest{project_ids: [Ecto.UUID.generate()]}
      {:ok, response} = Stub.describe_many(channel, request)

      assert response == %InternalApi.Repository.DescribeManyResponse{repositories: []}
    end

    test "should validate a request" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      invalid_assertions = [
        [project_ids: ["1"]],
        [project_ids: ["not-uuid"]],
        [repository_ids: ["1"]],
        [repository_ids: ["not-uuid"]]
      ]

      valid_assertions = [
        [project_ids: [Ecto.UUID.generate()]],
        [project_ids: []],
        [repository_ids: [Ecto.UUID.generate()]],
        [repository_ids: []],
        [repository_ids: [Ecto.UUID.generate()], project_ids: [Ecto.UUID.generate()]]
      ]

      for request_params <- valid_assertions do
        request = struct(InternalApi.Repository.DescribeManyRequest, request_params)

        response = Stub.describe_many(channel, request)

        assert match?({:ok, _}, response), "#{inspect(request)} should not fail"
      end

      for request_params <- invalid_assertions do
        request =
          %InternalApi.Repository.DescribeManyRequest{}
          |> Map.from_struct()
          |> Map.merge(Enum.into(request_params, %{}))
          |> then(&struct(InternalApi.Repository.DescribeManyRequest, &1))

        assert match?({:error, _}, Stub.describe_many(channel, request)), "#{inspect(request)} should fail"
      end
    end
  end
end
