defmodule HooksProcessor.Clients.ProjectHubClient.Test do
  use ExUnit.Case

  alias InternalApi.Projecthub.DescribeResponse
  alias HooksProcessor.Clients.ProjectHubClient

  @grpc_port 50_049

  setup_all do
    GRPC.Server.start(ProjectHubServiceMock, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(ProjectHubServiceMock)

      Test.Helpers.wait_until_stopped(ProjectHubServiceMock)
    end)

    {:ok, %{}}
  end

  test "describe() correctly timeouts if projecthub service takes to long to respond" do
    use_mock_projecthub_service()

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      :timer.sleep(5_500)
      %DescribeResponse{}
    end)

    assert {:error, message} = ProjectHubClient.describe("project_1")
    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = message

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "describe() returns error when projecthub service responds with anything but OK" do
    use_mock_projecthub_service()

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      %DescribeResponse{metadata: %{status: %{code: :NOT_FOUND, message: "Error"}}}
    end)

    assert {:error, message} = ProjectHubClient.describe("project_1")
    assert message == "Error"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "valid describe() response from server is processed correctly" do
    use_mock_projecthub_service()

    project_id = UUID.uuid4()
    org_id = UUID.uuid4()

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.metadata != nil

      %DescribeResponse{
        project: %{
          metadata: %{
            id: project_id,
            org_id: org_id
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    assert {:ok, project} = ProjectHubClient.describe("project_1")
    assert project.id == project_id
    assert project.org_id == org_id
    assert project.repository.pipeline_file == ".semaphore/semaphore.yml"
    assert project.repository.run_on == [:BRANCHES, :TAGS]
    assert project.repository.whitelist.tags == ["/v1.*/", "/release-.*/"]

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  defp use_mock_projecthub_service,
    do: Application.put_env(:hooks_processor, :projecthub_grpc_url, "localhost:#{inspect(@grpc_port)}")
end
