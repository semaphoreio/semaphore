defmodule HooksProcessor.Clients.BranchClient.Test do
  use ExUnit.Case

  alias InternalApi.Branch.{FindOrCreateResponse, DescribeResponse, ArchiveResponse}
  alias HooksProcessor.Clients.BranchClient

  @grpc_port 50_048

  setup_all do
    GRPC.Server.start(BranchServiceMock, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(BranchServiceMock)

      Test.Helpers.wait_until_stopped(BranchServiceMock)
    end)

    {:ok, %{}}
  end

  setup do
    webhook = %{
      id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      repository_id: UUID.uuid4(),
      received_at: DateTime.utc_now()
    }

    data = %{
      branch_name: "master",
      display_name: "master",
      pr_name: "",
      pr_number: 0
    }

    {:ok, %{webhook: webhook, data: data}}
  end

  # FindOrCreate

  test "find_or_create() correctly timeouts if server takes to long to respond", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:find_or_create, fn _req, _ ->
      :timer.sleep(5_500)
      %FindOrCreateResponse{}
    end)

    assert {:error, message} = BranchClient.find_or_create(ctx.webhook, ctx.data)
    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = message

    GrpcMock.verify!(BranchServiceMock)
  end

  test "find_or_create() returns error when server responds with anything but OK", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:find_or_create, fn _req, _ ->
      %FindOrCreateResponse{status: %{code: :BAD_PARAM, message: "Error"}}
    end)

    assert {:error, message} = BranchClient.find_or_create(ctx.webhook, ctx.data)
    assert message == "Error"

    GrpcMock.verify!(BranchServiceMock)
  end

  test "valid find_or_create() response from server is processed correctly", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:find_or_create, fn req, _ ->
      assert_request_valid(req, ctx)

      %FindOrCreateResponse{branch: %{id: "branch_1", name: "master"}, status: %{code: :OK}}
    end)

    assert {:ok, branch} = BranchClient.find_or_create(ctx.webhook, ctx.data)
    assert branch.id == "branch_1"
    assert branch.name == "master"

    GrpcMock.verify!(BranchServiceMock)
  end

  def assert_request_valid(req, %{webhook: webhook, data: data}) do
    assert req.project_id == webhook.project_id
    assert req.repository_id == webhook.repository_id
    assert req.name == data.branch_name
    assert req.display_name == data.display_name
    assert req.ref_type == :BRANCH
    assert req.pr_name == data.pr_name
    assert req.pr_number == data.pr_number
  end

  # Describe

  test "describe() correctly timeouts if server takes to long to respond", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      :timer.sleep(5_500)
      %DescribeResponse{}
    end)

    assert {:error, message} = BranchClient.describe(ctx.webhook, ctx.data)
    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = message

    GrpcMock.verify!(BranchServiceMock)
  end

  test "describe() returns error when server responds with anything but OK", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      %DescribeResponse{status: %{code: :BAD_PARAM, message: "Error"}}
    end)

    assert {:error, message} = BranchClient.describe(ctx.webhook, ctx.data)
    assert message == "Error"

    GrpcMock.verify!(BranchServiceMock)
  end

  test "valid describe() response from server is processed correctly", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.project_id == ctx.webhook.project_id
      assert req.branch_name == ctx.data.branch_name

      %DescribeResponse{branch: %{id: "branch_1", name: "master"}, status: %{code: :OK}}
    end)

    assert {:ok, branch} = BranchClient.describe(ctx.webhook, ctx.data)
    assert branch.id == "branch_1"
    assert branch.name == "master"

    GrpcMock.verify!(BranchServiceMock)
  end

  # Archive

  test "archive() correctly timeouts if server takes to long to respond", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:archive, fn _req, _ ->
      :timer.sleep(5_500)
      %ArchiveResponse{}
    end)

    assert {:error, message} = BranchClient.archive("branch_1", ctx.webhook)
    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = message

    GrpcMock.verify!(BranchServiceMock)
  end

  test "archive() returns error when server responds with anything but OK", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:archive, fn _req, _ ->
      %ArchiveResponse{status: %{code: :BAD_PARAM, message: "Error"}}
    end)

    assert {:error, message} = BranchClient.archive("branch_1", ctx.webhook)
    assert message == "Error"

    GrpcMock.verify!(BranchServiceMock)
  end

  test "valid archive() response from server is processed correctly", ctx do
    use_mock_branch_service()

    BranchServiceMock
    |> GrpcMock.expect(:archive, fn _req, _ ->
      %ArchiveResponse{status: %{code: :OK, message: "Success"}}
    end)

    assert {:ok, message} = BranchClient.archive("branch_1", ctx.webhook)
    assert message == "Branch successfully archived."

    GrpcMock.verify!(BranchServiceMock)
  end

  # Utility

  defp use_mock_branch_service,
    do: Application.put_env(:hooks_processor, :branch_api_grpc_url, "localhost:#{inspect(@grpc_port)}")
end
