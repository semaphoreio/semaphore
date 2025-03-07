defmodule Guard.Api.Gitlab do
  require Logger

  alias Guard.FrontRepo
  alias Guard.Utils.OAuth

  @base_url "https://gitlab.com"
  @oauth_path "/oauth/token"
  @oauth_token_info_path "#{@oauth_path}/info"

  @doc """
  Fetch or refresh access token
  """
  def user_token(repo_host_account) do
    cache_key = token_cache_key(repo_host_account.id)

    case Cachex.get(:token_cache, cache_key) do
      {:ok, {token, expires_at}} when not is_nil(token) and token != "" ->
        if OAuth.valid_token?(expires_at) do
          {:ok, {token, expires_at}}
        else
          handle_fetch_and_cache_token(repo_host_account)
        end

      _ ->
        handle_fetch_and_cache_token(repo_host_account)
    end
  end

  def validate_token(token) do
    client = build_validate_token_client(token)

    case Tesla.get(client, @oauth_token_info_path) do
      {:ok, res} ->
        expires_at = OAuth.calc_expires_at(res.body["expires_in"])
        {:ok, res.status in 200..299 && OAuth.valid_token?(expires_at)}

      {:error, error} ->
        Logger.error("Error validating token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp handle_fetch_and_cache_token(repo_host_account) do
    body_params = %{
      "grant_type" => "refresh_token",
      "refresh_token" => repo_host_account.refresh_token,
      "scope" => gitlab_scope()
    }

    client = build_token_client()

    case Tesla.post(client, @oauth_path, body_params) do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 200..299 ->
        OAuth.handle_ok_token_response(repo_host_account, body)

      {:ok, %Tesla.Env{status: status}} when status in 400..499 ->
        Logger.warning("Failed to refresh gitlab token, account might be revoked")
        {:error, :revoked}

      {:ok, %Tesla.Env{status: _status}} ->
        {:error, :failed}

      {:error, error} ->
        Logger.error("Error fetching gitlab token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp build_token_client do
    {:ok, {client_id, client_secret}} = Guard.GitProviderCredentials.get(:gitlab)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      {Tesla.Middleware.BasicAuth, username: client_id, password: client_secret},
      Tesla.Middleware.JSON
    ])
  end

  defp build_validate_token_client(token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      {Tesla.Middleware.BearerAuth, token: token},
      Tesla.Middleware.JSON
    ])
  end

  defp gitlab_scope do
    ueberauth_config = Application.fetch_env!(:ueberauth, Ueberauth)
    providers = ueberauth_config[:providers]
    {_, gitlab_config} = providers[:gitlab]

    gitlab_config[:default_scope]
  end

  defp token_cache_key(account_id), do: "gitlab_token_#{account_id}"

  defp update_refresh_token(repo_host_account, refresh_token) do
    FrontRepo.RepoHostAccount.update_refresh_token(repo_host_account, refresh_token)
  end
end
