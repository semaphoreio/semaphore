defmodule PipelinesAPI.ProjectClient.Test do
  use ExUnit.Case

  alias PipelinesAPI.ProjectClient

  @url_env_name "PROJECTHUB_API_GRPC_URL"
  @mock_server_port 50052

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    org = Support.Stubs.DB.first(:organizations)
    owner = Support.Stubs.DB.first(:users)
    project = Support.Stubs.Project.create(org, owner)

    {:ok, %{project: project}}
  end

  # describe call

  test "when URL is invalid in describe call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:12345")

    assert {:error, message} = ProjectClient.describe("project_id_1")
    assert {:timeout, _time_to_wait} = message

    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")
  end

  test "when time-out occures in describe call => error is returned" do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")

    assert {:error, message} = ProjectClient.describe("timeout")
    assert {:timeout, _time_to_wait} = message
  end

  test "when client.describe is called => gRPC server response is processed correctly", ctx do
    System.put_env(@url_env_name, "localhost:#{@mock_server_port}")

    assert {:ok, project} = ProjectClient.describe(ctx.project.id)
    assert project.spec.artifact_store_id == ctx.project.api_model.spec.artifact_store_id

    assert {:error, {:user, message}} = ProjectClient.describe("not_found")
    assert message == "project not_found not found"
  end
end
