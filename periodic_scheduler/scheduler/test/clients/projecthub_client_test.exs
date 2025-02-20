defmodule Scheduler.Clients.ProjecthubClient.Test do
  use ExUnit.Case
  alias Scheduler.Clients.ProjecthubClient

  @grpc_port 50_074
  setup_all do
    GRPC.Server.start(Test.MockProjectService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockProjectService)
    end)

    {:ok, %{}}
  end

  test "returns {:ok, project} when project service responds with OK" do
    user_mock_project_service()
    mock_project_service_response("ok")

    assert {:ok, project} = ProjecthubClient.describe("project_id")
    assert {:ok, _} = UUID.info(project.metadata.id)
    assert {:ok, _} = UUID.info(project.spec.repository.id)
  end

  test "returns {:error, timeout} when project service times out" do
    user_mock_project_service()
    mock_project_service_response("timeout")

    assert {:error, status} = ProjecthubClient.describe("project_id")
    assert status == {:timeout, 5000}
  end

  test "returns {:error, status} when project service responds with anything but OK" do
    user_mock_project_service()
    mock_project_service_response("failed_precondition")

    assert {:error, status} = ProjecthubClient.describe("project_id")
    assert status == %{code: :FAILED_PRECONDITION, message: "Failed precondition"}
  end

  defp user_mock_project_service(),
    do: Application.put_env(:scheduler, :projecthub_api_grpc_endpoint, "localhost:#{@grpc_port}")

  def mock_project_service_response(value),
    do: Application.put_env(:scheduler, :mock_project_service_response, value)
end
