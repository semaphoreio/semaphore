defmodule RepositoryHub.Server.ListActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.ListAction
  alias RepositoryHub.{InternalApiFactory, RepositoryModelFactory}

  setup do
    project_id = Ecto.UUID.generate()
    RepositoryModelFactory.seed_repositories(project_id: project_id)

    %{project_id: project_id}
  end

  describe "Universal ListAction" do
    test "should return a list of repositories", %{project_id: project_id} do
      request = InternalApiFactory.list_request(project_id: project_id)
      result = ListAction.execute(Adapters.pick!(request), request)

      assert {:ok, response} = result
      assert length(response.repositories) == 4
    end

    test "should return a list of empty repositories for project with no repositories" do
      request = InternalApiFactory.list_request(project_id: Ecto.UUID.generate())
      result = ListAction.execute(Adapters.pick!(request), request)

      assert {:ok, response} = result
      assert response == InternalApiFactory.list_response(repositories: [])
    end

    test "should validate a request" do
      request = InternalApiFactory.list_request(project_id: Ecto.UUID.generate())
      assert {:ok, _} = ListAction.validate(Adapters.universal(), request)
      assert {:error, _} = ListAction.validate(Adapters.universal(), %{request | project_id: ""})
      assert {:error, _} = ListAction.validate(Adapters.universal(), %{request | project_id: "not uuid"})
    end
  end
end
