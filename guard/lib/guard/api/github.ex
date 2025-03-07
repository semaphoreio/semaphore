defmodule Guard.Api.Github do
  require Logger

  use Tesla

  @oauth_base_url "https://github.com"
  @oauth_path "/login/oauth/access_token"

  plug(Tesla.Middleware.BaseUrl, "https://api.github.com")
  plug(Tesla.Middleware.JSON)

  def user(id) do
    case get("/user/" <> id) do
      {:ok, res} ->
        cond do
          res.status in 200..299 ->
            {:ok, %{id: res.body["id"] |> Integer.to_string(), login: res.body["login"]}}

          res.status == 404 ->
            Logger.debug("Error fetching user: #{inspect(res.body)}")

            {:error, :not_found}

          true ->
            Logger.debug("Error fetching user: #{inspect(res.body)}")

            {:error, "#{res.body["message"]}. #{res.body["documentation_url"]}"}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Fetch or refresh access token
  """
  def user_token(repo_host_account) do
    cache_key = token_cache_key(repo_host_account.id)

    case Cachex.get(:token_cache, cache_key) do
      {:ok, {token, expires_at}} when not is_nil(token) and token != "" ->
        if valid_token?(expires_at) do
          {:ok, {token, expires_at}}
        else
          handle_fetch_and_cache_token(repo_host_account)
        end

      _ ->
        handle_fetch_and_cache_token(repo_host_account)
    end
  end

  defp handle_static_token_or_fetch(rha) do
    case validate_token(rha.token) do
      {:ok, true} ->
        Cachex.put(:token_cache, token_cache_key(rha.id), {rha.token, nil})
        {:ok, {rha.token, nil}}

      _ ->
        handle_fetch_and_cache_token(rha)
    end
  end

  defp handle_fetch_and_cache_token(repo_host_account) do
    {:ok, {client_id, client_secret}} = Guard.GitProviderCredentials.get(:github)

    query_params = [
      grant_type: "refresh_token",
      refresh_token: repo_host_account.refresh_token,
      client_id: client_id,
      client_secret: client_secret
    ]

    client = build_token_client()

    case Tesla.post(client, @oauth_path, nil, query: query_params) do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 200..299 ->
        handle_ok_token_response(repo_host_account, body)

      {:ok, %Tesla.Env{status: status}} when status in 400..499 ->
        Logger.warning("Failed to refresh github token, account might be revoked")
        {:error, :revoked}

      {:ok, %Tesla.Env{status: _status}} ->
        {:error, :failed}

      {:error, error} ->
        Logger.error("Error fetching github token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp handle_ok_token_response(repo_host_account, body) do
    body =
      if is_binary(body) do
        Jason.decode!(body)
      else
        body
      end

    token = body["access_token"]
    expires_in = body["expires_in"]
    refresh_token = body["refresh_token"]

    expires_at = calc_expires_at(expires_in)

    if valid_token?(expires_at) do
      Cachex.put(:token_cache, token_cache_key(repo_host_account.id), {token, expires_at})
      update_refresh_token(repo_host_account, refresh_token)
    end

    {:ok, {token, expires_at}}
  end

  defp build_token_client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @oauth_base_url},
      Tesla.Middleware.JSON
    ])
  end

  # Case where the token never expires
  defp valid_token?(nil), do: true

  defp valid_token?(expires_at) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()
    # 5 minutes before expiration
    expires_at - 300 > current_time
  end

  defp calc_expires_at(nil), do: nil

  defp calc_expires_at(expires_in) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()
    current_time + expires_in
  end

  def validate_token(""), do: false

  def validate_token(token) do
    {:ok, {client_id, client_secret}} = Guard.GitProviderCredentials.get(:github)

    body = %{"access_token" => token}

    case post("/applications/#{client_id}/token", body,
           headers: authorization_headers(client_id, client_secret)
         ) do
      {:ok, res} ->
        is_valid = res.status in 200..299

        unless is_valid do
          Logger.error(
            "Token validation failed. status: #{res.status} body: #{inspect(res.body)}"
          )
        end

        {:ok, is_valid}

      {:error, error} ->
        Logger.error("Error validating token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp authorization_headers(client_id, client_secret) do
    [
      {"Accept", "application/vnd.github+json"},
      {"Authorization", "Basic " <> Base.encode64("#{client_id}:#{client_secret}")},
      {"X-GitHub-Api-Version", "2022-11-28"}
    ]
  end

  defp token_cache_key(account_id), do: "github_token_#{account_id}"

  defp update_refresh_token(repo_host_account, refresh_token) do
    Guard.FrontRepo.RepoHostAccount.update_refresh_token(repo_host_account, refresh_token)
  end
end
