defmodule RepositoryHub.GithubAppId do
  @moduledoc """
  Resolves the id of Semaphore's GitHub App, the same way github_hooks does:
  `GITHUB_APPLICATION_ID` when it is set, otherwise the GitHub App config in
  instance_config (open-source installs configure the app there, possibly
  after install).

  The instance_config value is cached for 10 minutes, so a reconfigured app is
  picked up without a restart. Lookup failures are not cached.
  """
  import RepositoryHub.Toolkit

  alias InternalApi.InstanceConfig.{ListConfigsRequest, InstanceConfigService}

  @cache :github_app_id_cache

  def child_spec(_opts) do
    import Cachex.Spec

    %{
      id: __MODULE__,
      start: {Cachex, :start_link, [@cache, [expiration: expiration(default: :timer.minutes(10))]]}
    }
  end

  @spec get() :: {:ok, String.t()} | {:error, map()}
  def get do
    case Application.get_env(:repository_hub, :github_application_id) do
      app_id when app_id not in [nil, ""] -> {:ok, app_id}
      _ -> from_instance_config()
    end
  end

  defp from_instance_config do
    @cache
    |> Cachex.fetch(:app_id, fn _key ->
      case fetch_from_instance_config() do
        {:ok, app_id} -> {:commit, app_id}
        error -> {:ignore, error}
      end
    end)
    |> case do
      {status, app_id} when status in [:ok, :commit] -> {:ok, app_id}
      {:ignore, error} -> error
      {:error, reason} -> fail_with(:unavailable, "GitHub App id cache error: #{inspect(reason)}")
    end
  end

  defp fetch_from_instance_config do
    case Application.get_env(:repository_hub, :instance_config_grpc_endpoint) do
      endpoint when endpoint in [nil, ""] ->
        log_error("GitHub App id is not configured: set GITHUB_APPLICATION_ID or INTERNAL_API_URL_INSTANCE_CONFIG")

        fail_with(
          :precondition,
          "GitHub App id is not configured: set GITHUB_APPLICATION_ID or INTERNAL_API_URL_INSTANCE_CONFIG"
        )

      endpoint ->
        fetch_from_instance_config(endpoint)
    end
  end

  defp fetch_from_instance_config(endpoint) do
    request = %ListConfigsRequest{types: [:CONFIG_TYPE_GITHUB_APP]}

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- list_configs(channel, request) do
      response.configs
      |> Enum.find(&(&1.type == :CONFIG_TYPE_GITHUB_APP and &1.state == :STATE_CONFIGURED))
      |> app_id_field()
    else
      error ->
        log_error("Failed to fetch the GitHub App config from instance_config: #{inspect(error)}")
        fail_with(:unavailable, "Can't fetch the GitHub App id from instance_config")
    end
  end

  defp list_configs(channel, request) do
    InstanceConfigService.Stub.list_configs(channel, request, timeout: 3_000)
  after
    GRPC.Stub.disconnect(channel)
  end

  defp app_id_field(nil), do: fail_with(:precondition, "GitHub App is not configured")

  defp app_id_field(config) do
    case Enum.find(config.fields, &(&1.key == "app_id")) do
      %{value: app_id} when app_id != "" -> {:ok, app_id}
      _ -> fail_with(:precondition, "GitHub App config has no app_id")
    end
  end
end
