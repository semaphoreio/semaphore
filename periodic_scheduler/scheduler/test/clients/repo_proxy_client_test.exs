defmodule Scheduler.Clients.RepoProxyClient.Test do
  use ExUnit.Case

  alias Scheduler.Clients.RepoProxyClient

  @grpc_port 50_034
  setup_all do
    GRPC.Server.start(Test.MockRepoProxyService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockRepoProxyService)
    end)

    {:ok, %{}}
  end

  test "returns {:ok, wf_id} when repo_proxy service responds with OK" do
    use_mock_repo_proxy_service()
    mock_repo_proxy_service_response("ok")

    assert {:ok, wf_id} = RepoProxyClient.create(%{triggered_by: :SCHEDULE})
    assert {:ok, _} = UUID.info(wf_id)
  end

  test "returns {:error, status} when repo_proxy service responds with anything but OK" do
    use_mock_repo_proxy_service()
    mock_repo_proxy_service_response("invalid_argument")

    assert {:error, {:error, grpc_error}} = RepoProxyClient.create(%{triggered_by: :SCHEDULE})
    assert grpc_error == %GRPC.RPCError{status: 3, message: "Invalid argument"}
  end

  test "returns error when it is not possible to connect to repo proxy service" do
    use_non_existing_repo_proxy_service()

    assert {:error, _} = RepoProxyClient.create(%{triggered_by: :SCHEDULE})

    use_mock_repo_proxy_service()
  end

  test "create() correctly timeouts if repo proxy service takes to long to respond" do
    use_mock_repo_proxy_service()
    mock_repo_proxy_service_response("timeout")

    assert {:error, _} = RepoProxyClient.create(%{triggered_by: :SCHEDULE})
  end

  defp use_non_existing_repo_proxy_service(),
    do: Application.put_env(:scheduler, :repo_proxy_api_grpc_endpoint, "something:12345")

  defp use_mock_repo_proxy_service(),
    do:
      Application.put_env(
        :scheduler,
        :repo_proxy_api_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  def mock_repo_proxy_service_response(value),
    do: Application.put_env(:scheduler, :mock_repo_proxy_service_response, value)
end
