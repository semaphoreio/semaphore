defmodule Guard.Api.Github do
  require Logger

  use Tesla

  alias Guard.Utils.OAuth

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

  # Important Considerations:
  - By default, GitHub tokens do not expire unless the optional setting in the GitHub app is changed.
  - If altered, the expires_in and refresh_token will not be null.
  - That's why we have refresh token logic for GitHub, even if it's not typically used.
  """
  def user_token(repo_host_account) do
    case validate_token(repo_host_account.token) do
      {:ok, %{valid: true}} -> {:ok, {repo_host_account.token, nil}}
      _ -> handle_fetch_token(repo_host_account)
    end
  end

  defp handle_fetch_token(%{refresh_token: refresh_token}) when refresh_token in [nil, ""] do
    Logger.warning("No refresh token found for GitHub repo host account, account is revoked")
    {:error, :revoked}
  end

  defp handle_fetch_token(repo_host_account) do
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
        OAuth.handle_ok_token_response(repo_host_account, body)

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

  defp build_token_client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @oauth_base_url},
      Tesla.Middleware.JSON
    ])
  end

  @doc """
  Validate a GitHub OAuth token by calling the authenticated `/user` endpoint.

  Returns a map with the freshest known profile fields (`login`, `uid`) so
  callers can opportunistically sync changes (e.g. GitHub login renames)
  without a second API round trip.

  - `{:ok, %{valid: true, login: login, uid: uid}}` on 2xx
  - `{:ok, %{valid: false, login: nil, uid: nil}}` on 4xx (token rejected)
  - `{:error, :network_error}` on transport failure
  """
  def validate_token(""), do: {:ok, %{valid: false, login: nil, uid: nil}}

  def validate_token(token) do
    case get("/user", headers: authorization_headers(token)) do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 200..299 ->
        {:ok, %{valid: true, login: body["login"], uid: stringify_uid(body["id"])}}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.error("Token validation failed. status: #{status} body: #{inspect(body)}")
        {:ok, %{valid: false, login: nil, uid: nil}}

      {:error, error} ->
        Logger.error("Error validating token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp stringify_uid(nil), do: nil
  defp stringify_uid(id) when is_integer(id), do: Integer.to_string(id)
  defp stringify_uid(id), do: to_string(id)

  defp authorization_headers(token) do
    [
      {"Authorization", "token #{token}"}
    ]
  end
end
