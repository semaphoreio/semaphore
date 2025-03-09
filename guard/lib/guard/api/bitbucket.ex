defmodule Guard.Api.Bitbucket do
  require Logger
  use Tesla
  alias Guard.Utils.OAuth

  @api_base_url "https://api.bitbucket.org"
  @base_url "https://bitbucket.org"
  @api_v2_path "/api/2.0"
  @oauth2_path "/site/oauth2/access_token"

  plug(Tesla.Middleware.BaseUrl, @base_url)
  plug(Tesla.Middleware.JSON)

  def user(id) do
    case get("#{@api_v2_path}/users/#{id}") do
      {:ok, res} ->
        if res.status in 200..299 do
          {:ok,
           %{
             id: res.body["uuid"],
             login: res.body["nickname"],
             account_id: res.body["account_id"]
           }}
        else
          Logger.debug("Error fetching user: #{inspect(res.body)}")
          {:error, "#{res.body["error"]["message"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Fetch or refresh access token
  """
  def user_token(repo_host_account) do
    cache_key = OAuth.token_cache_key(repo_host_account)

    case Cachex.get(:token_cache, cache_key) do
      {:ok, {token, expires_at}} when not is_nil(token) and token != "" ->
        if OAuth.valid_token?(expires_at) do
          {:ok, {token, expires_at}}
        else
          fetch_and_cache_token(repo_host_account)
        end

      _ ->
        fetch_and_cache_token(repo_host_account)
    end
  end

  def validate_token(token) do
    client = build_validate_token_client()

    case Tesla.get(client, "/repositories?access_token=#{token}") do
      {:ok, res} ->
        {:ok, res.status in 200..299}

      {:error, error} ->
        Logger.error("Error validating token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp fetch_and_cache_token(repo_host_account) do
    body_params = %{
      "grant_type" => "refresh_token",
      "refresh_token" => repo_host_account.refresh_token
    }

    client = build_token_client()

    case Tesla.post(client, @oauth2_path, body_params) do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 200..299 ->
        OAuth.handle_ok_token_response(repo_host_account, body)

      {:ok, %Tesla.Env{status: status}} when status in 400..499 ->
        Logger.warn("Failed to refresh token, account might be revoked")
        {:error, :revoked}

      {:ok, %Tesla.Env{status: _status}} ->
        {:error, :failed}

      {:error, error} ->
        Logger.error("Error fetching token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp build_token_client do
    {:ok, {client_id, client_secret}} = Guard.GitProviderCredentials.get(:bitbucket)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, @base_url},
      {Tesla.Middleware.BasicAuth, username: client_id, password: client_secret},
      Tesla.Middleware.FormUrlencoded
    ])
  end

  defp build_validate_token_client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "#{@api_base_url}/2.0"},
      Tesla.Middleware.JSON
    ])
  end
end
