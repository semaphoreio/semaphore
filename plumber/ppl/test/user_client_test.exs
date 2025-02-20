defmodule Ppl.UserClient.Test do
  use ExUnit.Case

  alias Util.Proto
  alias Ppl.UserClient
  alias InternalApi.User.DescribeResponse

  @url_env_name "INTERNAL_API_URL_USER"
  @mock_server_port 59_730

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(UserServiceMock)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, port)
    :ok
  end

  # describe (List call)

  test "when URL is invalid in describe call => timeout occures" do
    System.put_env(@url_env_name, "invalid_url:12345")

    assert {:error, message} = UserClient.describe("user_id_1")
    assert {:timeout, _time_to_wait} = message
  end

  test "when time-out occures in describe call => error is returned" do
    UserServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
        :timer.sleep(5_000)
        DescribeResponse.new()
      end)

    assert {:error, message} = UserClient.describe("user_id_1")
    assert {:timeout, _time_to_wait} = message

    GrpcMock.verify!(UserServiceMock)
  end

  test "when client.describe is called => gRPC server response is processed correctly" do
    UserServiceMock
    |> GrpcMock.expect(:describe, fn %{user_id: user_id}, _ ->
        %{github_login: user_id, status: %{code: :OK}}
        |> Proto.deep_new!(DescribeResponse)
      end)
    |> GrpcMock.expect(:describe, fn req, _ ->
        message = "The user with id '#{req.user_id}' is not found."
        %{status: %{code: :BAD_PARAM, message: message}}
        |> Proto.deep_new!(DescribeResponse)
      end)

    assert {:ok, user} =  UserClient.describe("user_id_1")
    assert user.github_login == "user_id_1"

    assert {:error, message} =  UserClient.describe("user_id_1")
    assert message == "The user with id 'user_id_1' is not found."

    GrpcMock.verify!(UserServiceMock)
  end
end
