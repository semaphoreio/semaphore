defmodule HooksProcessor.Clients.RBACClient.Test do
  use ExUnit.Case

  alias InternalApi.RBAC.ListUserPermissionsResponse
  alias HooksProcessor.Clients.RBACClient

  @grpc_port 50_047

  setup_all do
    GRPC.Server.start(RBACServiceMock, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(RBACServiceMock)

      Test.Helpers.wait_until_stopped(RBACServiceMock)
    end)

    {:ok, %{}}
  end

  setup do
    user = %{
      id: UUID.uuid4()
    }

    org = %{
      id: UUID.uuid4()
    }

    {:ok, %{user: user, org: org}}
  end

  test "member?() correctly timeouts if server takes to long to respond", ctx do
    use_mock_rbac_service()

    RBACServiceMock
    |> GrpcMock.expect(:list_user_permissions, fn _req, _ ->
      :timer.sleep(5_500)
      %ListUserPermissionsResponse{}
    end)

    assert {:error, message} = RBACClient.member?(ctx.org.id, ctx.user.id)

    assert %GRPC.RPCError{message: "Deadline expired", status: 4} = message

    GrpcMock.verify!(RBACServiceMock)
  end

  test "member?() returns error when server responds with error", ctx do
    use_mock_rbac_service()

    RBACServiceMock
    |> GrpcMock.expect(:list_user_permissions, fn _req, _ ->
      raise %GRPC.RPCError{message: "Error", status: 2}
    end)

    assert {:error, error} = RBACClient.member?(ctx.org.id, ctx.user.id)

    assert error.message == "Error"

    GrpcMock.verify!(RBACServiceMock)
  end

  test "member?() returns true is user has permissions in organization", ctx do
    use_mock_rbac_service()

    RBACServiceMock
    |> GrpcMock.expect(:list_user_permissions, fn req, _ ->
      assert req.org_id == ctx.org.id
      assert req.user_id == ctx.user.id

      %ListUserPermissionsResponse{
        user_id: req.user_id,
        org_id: req.org_id,
        project_id: req.project_id,
        permissions: ["foo", "bar"]
      }
    end)

    assert {:ok, true} = RBACClient.member?(ctx.org.id, ctx.user.id)

    GrpcMock.verify!(RBACServiceMock)
  end

  test "member?() returns false if user do not have permissions in organization", ctx do
    use_mock_rbac_service()

    RBACServiceMock
    |> GrpcMock.expect(:list_user_permissions, fn req, _ ->
      assert req.org_id == ctx.org.id
      assert req.user_id == ctx.user.id

      %ListUserPermissionsResponse{
        user_id: req.user_id,
        org_id: req.org_id,
        project_id: req.project_id,
        permissions: []
      }
    end)

    assert {:ok, false} = RBACClient.member?(ctx.org.id, ctx.user.id)

    GrpcMock.verify!(RBACServiceMock)
  end

  # Utility

  defp use_mock_rbac_service,
    do: Application.put_env(:hooks_processor, :rbac_api_grpc_url, "localhost:#{inspect(@grpc_port)}")
end
