defmodule Guard.Id.MaybeSetupGitProviders do
  @behaviour Plug

  require Logger

  @ttl :timer.seconds(60) * 10

  defmodule GitProviderBehaviour do
    @moduledoc """
    Behaviour and implementations for different Git providers (GitHub, Bitbucket).
    """

    @callback oauth_config_key() :: atom()
    @callback cooldown_key() :: String.t()
    @callback additional_opts() :: list()
    @callback provider_type() :: :github | :bitbucket | :gitlab
  end

  defmodule Github do
    @behaviour Guard.Id.MaybeSetupGitProviders.GitProviderBehaviour

    @impl true
    def provider_type, do: :github

    @impl true
    def oauth_config_key, do: Ueberauth.Strategy.Github.OAuth

    @impl true
    def cooldown_key, do: "CONFIG_TYPE_GITHUB_APP_last_fetched"

    @impl true
    def additional_opts, do: []
  end

  defmodule Bitbucket do
    @behaviour Guard.Id.MaybeSetupGitProviders.GitProviderBehaviour

    @impl true
    def provider_type, do: :bitbucket

    @impl true
    def oauth_config_key, do: Ueberauth.Strategy.Bitbucket.OAuth

    @impl true
    def cooldown_key, do: "CONFIG_TYPE_BITBUCKET_APP_last_fetched"

    @impl true
    def additional_opts, do: []
  end

  defmodule Gitlab do
    @behaviour Guard.Id.MaybeSetupGitProviders.GitProviderBehaviour

    @impl true
    def provider_type, do: :gitlab

    @impl true
    def oauth_config_key, do: Ueberauth.Strategy.Gitlab.OAuth

    @impl true
    def cooldown_key, do: "CONFIG_TYPE_GITLAB_APP_last_fetched"

    @impl true
    def additional_opts,
      do: [redirect_uri: "https://id.#{System.get_env("BASE_DOMAIN")}/oauth/gitlab/callback"]
  end

  defmodule GitProvider do
    def providers, do: [Github, Bitbucket, Gitlab]
  end

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.debug("MaybeSetupGitProviders.call")

    GitProvider.providers()
    |> Enum.reduce_while(:ok, fn provider, _acc ->
      case maybe_setup_credentials(provider) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
    |> case do
      :ok ->
        conn

      error ->
        Logger.error("MaybeSetupGitProviders.call: failed: #{inspect(error)}")
        conn
    end
  end

  defp maybe_setup_credentials(provider) do
    provider_name = provider |> Module.split() |> List.last() |> String.downcase()

    with {:fetch, true} <- should_fetch?(provider),
         {:ok, {client_id, client_secret}} <-
           Guard.GitProviderCredentials.get(provider.provider_type()),
         :ok <- setup_env(provider, %{client_id: client_id, client_secret: client_secret}),
         {:ok, true} <- set_cooldown(provider) do
      Logger.debug(fn ->
        "MaybeSetupGitProviders.#{provider_name}: success: env: #{inspect(get_env(provider))}"
      end)

      :ok
    else
      {:fetch, false} ->
        :ok

      {:error, :not_found} ->
        :ok

      error ->
        Logger.debug("MaybeSetupGitProviders.#{provider_name}: failed: #{inspect(error)}")
        error
    end
  end

  defp should_fetch?(provider) do
    case env_empty?(provider) do
      true -> {:fetch, true}
      false -> {:fetch, cooldown_expired?(provider)}
    end
  end

  defp env_empty?(provider) do
    env = get_env(provider)

    empty_env =
      env
      |> Enum.any?(fn {_, v} -> v == "" || is_nil(v) end)

    empty_env or env == nil or env == []
  end

  defp get_env(provider) do
    Application.get_env(:ueberauth, provider.oauth_config_key())
  end

  defp setup_env(provider, credentials) do
    opts =
      provider.additional_opts() ++
        [client_id: credentials.client_id, client_secret: credentials.client_secret]

    Application.put_env(:ueberauth, provider.oauth_config_key(), opts)
  end

  defp set_cooldown(provider) do
    Cachex.put(:config_cache, provider.cooldown_key(), DateTime.utc_now(), ttl: @ttl)
  end

  defp cooldown_expired?(provider) do
    Cachex.exists?(:config_cache, provider.cooldown_key())
    |> case do
      {:ok, true} -> true
      _ -> false
    end
  end
end
