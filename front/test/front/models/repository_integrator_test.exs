defmodule Front.Models.RepositoryIntegratorTest do
  use ExUnit.Case

  alias Front.Models.RepositoryIntegrator

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    project_stub = Support.Stubs.DB.first(:projects)
    project = Front.Models.Project.find(project_stub.id, project_stub.org_id)

    [project: project]
  end

  describe ".get_repository_token" do
    test "returns token when valid response is received from server", %{project: project} do
      user_id = UUID.uuid4()
      assert {:ok, token} = RepositoryIntegrator.get_repository_token(project, user_id)
      assert token == "valid_token_value"
    end

    test "returns error when server responds with error", %{project: project} do
      user_id = "invalid_response"
      assert {:error, error} = RepositoryIntegrator.get_repository_token(project, user_id)
      assert error == %GRPC.RPCError{status: 3, message: "Invalid request."}
    end
  end
end
