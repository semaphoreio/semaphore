defmodule HooksProcessor.Clients.UserClient.Test do
  use ExUnit.Case

  alias InternalApi.User.{User, DescribeResponse}
  alias HooksProcessor.Clients.UserClient

  @grpc_port 50_046

  setup_all do
    GRPC.Server.start(UserServiceMock, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(UserServiceMock)

      Test.Helpers.wait_until_stopped(UserServiceMock)
    end)

    {:ok, %{}}
  end

  setup do
    provider = %{
      uid: UUID.uuid4(),
      type: "bitbucket"
    }

    user = %{
      id: UUID.uuid4()
    }

    email = "foo@example.com"

    {:ok, %{provider: provider, user: user, email: email}}
  end

  # Describe

  test "describe() correctly timeouts if server takes to long to respond", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      :timer.sleep(5_500)
      %DescribeResponse{}
    end)

    assert {:error, message} = UserClient.describe(ctx.user.id)

    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = message

    GrpcMock.verify!(UserServiceMock)
  end

  test "describe() returns error when server responds with error", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      raise %GRPC.RPCError{message: "Error", status: 2}
    end)

    assert {:error, error} = UserClient.describe(ctx.user.id)

    assert error.message == "Error"

    GrpcMock.verify!(UserServiceMock)
  end

  test "valid describe() response from server is processed correctly", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.user_id == ctx.user.id

      %DescribeResponse{user: %{id: ctx.user.id, name: "John"}}
    end)

    assert {:ok, user} = UserClient.describe(ctx.user.id)
    assert user.id == ctx.user.id
    assert user.name == "John"

    GrpcMock.verify!(UserServiceMock)
  end

  # DescribeByRepositoryProvider

  test "describe_by_repository_provider() correctly timeouts if server takes to long to respond", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe_by_repository_provider, fn _req, _ ->
      :timer.sleep(5_500)
      %User{}
    end)

    assert {:error, message} = UserClient.describe_by_repository_provider(ctx.provider.uid, ctx.provider.type)

    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = message

    GrpcMock.verify!(UserServiceMock)
  end

  test "describe_by_repository_provider() returns error when server responds with error", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe_by_repository_provider, fn _req, _ ->
      raise %GRPC.RPCError{message: "Error", status: 2}
    end)

    assert {:error, error} = UserClient.describe_by_repository_provider(ctx.provider.uid, ctx.provider.type)

    assert error.message == "Error"

    GrpcMock.verify!(UserServiceMock)
  end

  test "valid describe_by_repository_provider() response from server is processed correctly", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe_by_repository_provider, fn req, _ ->
      assert req.provider.uid == ctx.provider.uid
      assert req.provider.type == ctx.provider.type |> String.upcase() |> String.to_atom()

      %User{id: "branch_1", name: "master"}
    end)

    assert {:ok, user} = UserClient.describe_by_repository_provider(ctx.provider.uid, ctx.provider.type)
    assert user.id == "branch_1"
    assert user.name == "master"

    GrpcMock.verify!(UserServiceMock)
  end

  # DescribeByEmail

  test "describe_by_email() correctly timeouts if server takes to long to respond", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe_by_email, fn _req, _ ->
      :timer.sleep(5_500)
      %User{}
    end)

    assert {:error, message} = UserClient.describe_by_email(ctx.email)

    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = message

    GrpcMock.verify!(UserServiceMock)
  end

  test "describe_by_email() returns error when server responds with error", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe_by_email, fn _req, _ ->
      raise %GRPC.RPCError{message: "Error", status: 2}
    end)

    assert {:error, error} = UserClient.describe_by_email(ctx.email)

    assert error.message == "Error"

    GrpcMock.verify!(UserServiceMock)
  end

  test "valid describe_by_email() response from server is processed correctly", ctx do
    use_mock_user_service()

    UserServiceMock
    |> GrpcMock.expect(:describe_by_email, fn req, _ ->
      assert req.email == ctx.email

      %User{id: "branch_1", name: "master"}
    end)

    assert {:ok, user} = UserClient.describe_by_email(ctx.email)
    assert user.id == "branch_1"
    assert user.name == "master"

    GrpcMock.verify!(UserServiceMock)
  end

  # Utility

  defp use_mock_user_service,
    do: Application.put_env(:hooks_processor, :user_api_grpc_url, "localhost:#{inspect(@grpc_port)}")
end
