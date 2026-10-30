defmodule RepositoryHub.GithubAppIdTest do
  use ExUnit.Case, async: false

  import Mock

  alias InternalApi.InstanceConfig.{Config, ConfigField, ListConfigsResponse}
  alias InternalApi.InstanceConfig.InstanceConfigService.Stub
  alias RepositoryHub.GithubAppId

  setup do
    previous = Application.get_env(:repository_hub, :github_application_id)
    previous_endpoint = Application.get_env(:repository_hub, :instance_config_grpc_endpoint)
    Cachex.clear(:github_app_id_cache)

    on_exit(fn ->
      Application.put_env(:repository_hub, :github_application_id, previous)
      Application.put_env(:repository_hub, :instance_config_grpc_endpoint, previous_endpoint)
      Cachex.clear(:github_app_id_cache)
    end)
  end

  defp github_app_config(state, fields) do
    %Config{
      type: :CONFIG_TYPE_GITHUB_APP,
      state: state,
      fields: Enum.map(fields, fn {key, value} -> %ConfigField{key: key, value: value} end)
    }
  end

  defp instance_config_mocks(list_configs) do
    [
      {GRPC.Stub, [:passthrough],
       [connect: fn _endpoint -> {:ok, :channel} end, disconnect: fn channel -> {:ok, channel} end]},
      {Stub, [], [list_configs: list_configs]}
    ]
  end

  test "uses GITHUB_APPLICATION_ID when set, without calling instance_config" do
    Application.put_env(:repository_hub, :github_application_id, "123")

    with_mocks(instance_config_mocks(fn _, _, _ -> raise "must not be called" end)) do
      assert {:ok, "123"} = GithubAppId.get()
    end
  end

  describe "without GITHUB_APPLICATION_ID" do
    setup do
      Application.put_env(:repository_hub, :github_application_id, nil)
    end

    test "reads app_id from the configured GitHub App in instance_config and caches it" do
      response = %ListConfigsResponse{
        configs: [github_app_config(:STATE_CONFIGURED, [{"pem", "secret"}, {"app_id", "456"}])]
      }

      with_mocks(instance_config_mocks(fn _, _, _ -> {:ok, response} end)) do
        assert {:ok, "456"} = GithubAppId.get()
        assert {:ok, "456"} = GithubAppId.get()
        assert_called_exactly(Stub.list_configs(:_, :_, :_), 1)
        assert_called_exactly(GRPC.Stub.disconnect(:channel), 1)
      end
    end

    test "fails when the GitHub App is not configured" do
      response = %ListConfigsResponse{configs: [github_app_config(:STATE_EMPTY, [{"app_id", "456"}])]}

      with_mocks(instance_config_mocks(fn _, _, _ -> {:ok, response} end)) do
        assert {:error, %{status: status}} = GithubAppId.get()
        assert status == GRPC.Status.failed_precondition()
      end
    end

    test "fails with a clear message when neither the env nor instance_config is configured" do
      Application.put_env(:repository_hub, :instance_config_grpc_endpoint, nil)

      with_mocks(instance_config_mocks(fn _, _, _ -> raise "must not be called" end)) do
        assert {:error, %{status: status, message: message}} = GithubAppId.get()
        assert status == GRPC.Status.failed_precondition()
        assert message =~ "GITHUB_APPLICATION_ID"
        refute called(GRPC.Stub.connect(:_))
      end
    end

    test "fails as unavailable when instance_config can't be reached, and doesn't cache it" do
      with_mocks(instance_config_mocks(fn _, _, _ -> {:error, %GRPC.RPCError{status: 14}} end)) do
        assert {:error, %{status: status}} = GithubAppId.get()
        assert status == GRPC.Status.unavailable()
        assert {:error, _} = GithubAppId.get()
        assert_called_exactly(Stub.list_configs(:_, :_, :_), 2)
        assert_called_exactly(GRPC.Stub.disconnect(:channel), 2)
      end
    end
  end
end
