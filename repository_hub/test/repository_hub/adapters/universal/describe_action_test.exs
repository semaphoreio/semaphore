defmodule RepositoryHub.Server.DescribeActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{Adapters, Model}
  alias RepositoryHub.Server.DescribeAction
  alias RepositoryHub.{InternalApiFactory, RepositoryModelFactory, DeployKeysModelFactory}

  setup do
    {:ok, repository} = RepositoryModelFactory.create_repository()

    %{request: InternalApiFactory.describe_request(repository_id: repository.id), repository: repository}
  end

  describe "Universal DescribeAction" do
    test "should return a repository", %{request: request, repository: repository} do
      result = DescribeAction.execute(Adapters.pick!(request), request)

      assert {:ok, response} = result
      assert response.repository == Model.Repositories.to_grpc_model(repository)
    end

    test "should return a repository with an SSH key if requested", %{request: request, repository: repository} do
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id)
      request = %{request | include_private_ssh_key: true}
      result = DescribeAction.execute(Adapters.pick!(request), request)

      assert {:ok, response} = result
      assert response.repository == Model.Repositories.to_grpc_model(repository)
      assert response.private_ssh_key != ""
    end

    test "should return a repository without an SSH if requested SSH key is not found", %{
      request: request,
      repository: repository
    } do
      request = %{request | include_private_ssh_key: true}
      result = DescribeAction.execute(Adapters.pick!(request), request)

      assert {:ok, response} = result
      assert response.repository == Model.Repositories.to_grpc_model(repository)
      assert response.private_ssh_key == ""
    end

    test "should fail when repository doesnt exist", %{request: request} do
      request = %{request | repository_id: Ecto.UUID.generate()}
      result = DescribeAction.execute(Adapters.pick!(request), request)

      assert {:error, _} = result
    end

    test "should validate a request", %{request: request} do
      assert {:ok, _} = DescribeAction.validate(Adapters.universal(), request)
      assert {:error, _} = DescribeAction.validate(Adapters.universal(), %{request | repository_id: ""})
      assert {:error, _} = DescribeAction.validate(Adapters.universal(), %{request | repository_id: "not uuid"})
    end
  end
end
