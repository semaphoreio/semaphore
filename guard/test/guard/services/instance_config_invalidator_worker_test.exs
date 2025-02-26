defmodule Guard.Services.InstanceConfigInvalidatorWorker.Test do
  use Guard.RepoCase

  setup do
    Support.Guard.Store.clear!()

    :ok
  end

  describe ".handle_message" do
    test "Message processes and invalidates the cache" do
      Cachex.put(:config_cache, "github_credentials", %{})
      Cachex.put(:config_cache, "gitlab_credentials", %{})
      Cachex.put(:config_cache, "bitbucket_credentials", %{})

      [
        :CONFIG_TYPE_GITHUB_APP,
        :CONFIG_TYPE_BITBUCKET_APP,
        :CONFIG_TYPE_GITLAB_APP
      ]
      |> Enum.each(fn type ->
        InternalApi.InstanceConfig.ConfigType.value(type)
        |> publish_event()
      end)

      :timer.sleep(1000)

      assert {:ok, false} == Cachex.exists?(:config_cache, "github_credentials")
      assert {:ok, false} == Cachex.exists?(:config_cache, "gitlab_credentials")
      assert {:ok, false} == Cachex.exists?(:config_cache, "bitbucket_credentials")
    end
  end

  #
  # Helpers
  #

  defp publish_event(type) do
    Guard.Events.ConfigModified.publish(type)
  end
end
