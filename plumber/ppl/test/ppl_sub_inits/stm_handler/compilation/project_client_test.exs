defmodule Ppl.PplSubInits.STMHandler.Compilation.ProjectClient.Test do
  use ExUnit.Case

  alias Util.Proto
  alias InternalApi.Projecthub.DescribeResponse
  alias Ppl.PplSubInits.STMHandler.Compilation.ProjectClient

  @url_env_name "INTERNAL_API_URL_PROJECT"

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(ProjectServiceMock)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, port)
    :ok
  end

  # describe call

  test "when URL is invalid in describe call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:0")

    assert {:error, message} = ProjectClient.describe("project_id_1")
    assert {:timeout, _time_to_wait} = message
  end

  test "when time-out occures in describe call => error is returned" do
    ProjectServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
        :timer.sleep(5_000)
        DescribeResponse.new()
      end)

    assert {:error, message} = ProjectClient.describe("project_id_1")
    assert {:timeout, _time_to_wait} = message

    GrpcMock.verify!(ProjectServiceMock)
  end

  test "when client.describe is called => gRPC server response is processed correctly" do
    ProjectServiceMock
    |> GrpcMock.expect(:describe, fn %{id: project_id}, _ ->
        %{
          metadata: %{status: %{code: :OK}},
          project: %{spec: %{artifact_store_id: project_id}}
        }
        |> Proto.deep_new!(DescribeResponse)
      end)
    |> GrpcMock.expect(:describe, fn req, _ ->
        message = "The project with id '#{req.id}' is not found."
        %{
          metadata: %{
            status: %{
              code: :NOT_FOUND,
              message: message
            }
          }
        }
        |> Proto.deep_new!(DescribeResponse)
      end)

    assert {:ok, project} = ProjectClient.describe("project_id_1")
    assert project.spec.artifact_store_id == "project_id_1"

    assert {:error, message} = ProjectClient.describe("project_id_1")
    assert message == "The project with id 'project_id_1' is not found."

    GrpcMock.verify!(ProjectServiceMock)
  end
end
