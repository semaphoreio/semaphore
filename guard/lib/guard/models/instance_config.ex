defmodule Guard.Models.InstanceConfig do
  alias InternalApi.InstanceConfig, as: API
  require Logger
  @ttl :timer.seconds(60) * 5

  def fetch_github_app_config do
    fetch_app_config(:github)
  end

  def fetch_bitbucket_app_config do
    fetch_app_config(:bitbucket)
  end

  def fetch_gitlab_app_config do
    fetch_app_config(:gitlab)
  end

  def field(config, field) do
    config.fields
    |> Enum.find(fn f -> f.key == field end)
    |> Map.get(:value)
  end

  defp fetch_app_config(provider) do
    {config_type, cache_key} = get_provider_config(provider)

    fetch_app_from_cache(provider, config_type, cache_key)
    |> case do
      {:ok, config} -> {:ok, config}
      {:commit, config, _} -> {:ok, config}
      _ -> {:error, :not_found}
    end
  end

  defp fetch_app_from_cache(provider, config_type, cache_key) do
    Cachex.fetch(:config_cache, cache_key, fn _key ->
      with {:ok, response} <- list_configs([config_type]),
           {:ok, config} <- extract_app_config(response, config_type) do
        {:commit, config, ttl: @ttl}
      else
        {:error, grpc_err = %GRPC.RPCError{}} ->
          Logger.error(
            "Failed to fetch #{provider_name(provider)} App config: #{inspect(grpc_err.message)}"
          )

          {:ignore, nil}

        e ->
          Logger.error("Failed to fetch #{provider_name(provider)} App config: #{inspect(e)}")
          {:ignore, nil}
      end
    end)
  end

  defp extract_app_config(response, config_type) do
    Enum.find(response.configs, {:error, :not_found}, fn config ->
      API.ConfigType.key(config.type) == config_type and
        API.State.key(config.state) == :STATE_CONFIGURED
    end)
    |> case do
      {:error, :not_found} -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  defp get_provider_config(:github), do: {:CONFIG_TYPE_GITHUB_APP, "CONFIG_TYPE_GITHUB_APP"}

  defp get_provider_config(:bitbucket),
    do: {:CONFIG_TYPE_BITBUCKET_APP, "CONFIG_TYPE_BITBUCKET_APP"}

  defp get_provider_config(:gitlab),
    do: {:CONFIG_TYPE_GITLAB_APP, "CONFIG_TYPE_GITLAB_APP"}

  defp provider_name(:github), do: "GitHub"
  defp provider_name(:bitbucket), do: "Bitbucket"
  defp provider_name(:gitlab), do: "GitLab"

  defp list_configs(types) do
    request = %API.ListConfigsRequest{types: Enum.map(types, &API.ConfigType.value/1)}

    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:guard, :instance_config_grpc_endpoint))

    API.InstanceConfigService.Stub.list_configs(channel, request)
  end
end
