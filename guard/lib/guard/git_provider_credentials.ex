defmodule Guard.GitProviderCredentials do
  require Logger

  alias Guard.Models.InstanceConfig, as: IC

  @type provider :: :github | :bitbucket | :gitlab
  @type credentials :: {String.t(), String.t()}

  @spec get(provider) :: {:ok, credentials} | {:error, any}
  def get(provider) do
    if Application.get_env(:guard, :include_instance_config) do
      # even with instance config first check local config
      case get_from_config(provider) do
        {:ok, credentials} -> {:ok, credentials}
        _ -> get_from_cache_or_instance(provider)
      end
      |> case do
        {:ok, credentials} ->
          {:ok, {credentials.client_id, credentials.client_secret}}

        {:error, :not_found} ->
          {:error, :not_found}

        error ->
          {:error, error}
      end
    else
      credentials = Application.fetch_env!(:guard, provider)

      {:ok, {credentials[:client_id], credentials[:client_secret]}}
    end
  end

  defp get_from_config(provider) do
    case Application.get_env(:guard, provider) do
      %{client_id: client_id, client_secret: client_secret}
      when not is_nil(client_id) and not is_nil(client_secret) ->
        {:ok, %{client_id: client_id, client_secret: client_secret}}

      _ ->
        :error
    end
  end

  @spec get_from_cache_or_instance(provider) :: {:ok, credentials} | {:error, any}
  defp get_from_cache_or_instance(provider) do
    cache_key = "#{provider}_credentials"

    case Cachex.get(:config_cache, cache_key) do
      {:ok, %{client_id: client_id, client_secret: client_secret} = credentials}
      when not is_nil(client_id) and not is_nil(client_secret) ->
        {:ok, credentials}

      _ ->
        fetch_from_instance_config(provider, cache_key)
    end
  end

  defp fetch_from_instance_config(provider, cache_key) do
    fetch_fn =
      case provider do
        :github -> &IC.fetch_github_app_config/0
        :bitbucket -> &IC.fetch_bitbucket_app_config/0
        :gitlab -> &IC.fetch_gitlab_app_config/0
      end

    case fetch_fn.() do
      {:ok, app_config} ->
        credentials = %{
          client_id: IC.field(app_config, "client_id"),
          client_secret: IC.field(app_config, "client_secret")
        }

        Logger.debug(fn ->
          "#{inspect(provider)} credentials fetch: success: #{inspect(credentials)}"
        end)

        Cachex.put(:config_cache, cache_key, credentials)
        {:ok, credentials}

      error ->
        error
    end
  end
end
