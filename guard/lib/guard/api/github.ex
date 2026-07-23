defmodule Guard.Api.Github do
  require Logger

  use Tesla

  alias Guard.Utils.OAuth

  @oauth_base_url "https://github.com"
  @oauth_path "/login/oauth/access_token"

  plug(Tesla.Middleware.BaseUrl, "https://api.github.com")
  plug(Tesla.Middleware.JSON)

  @doc """
  Fetch a GitHub user by numeric UID.

  When a non-nil/non-empty `token` is provided, the request is sent
  authenticated (uses the per-user OAuth quota: 5000 req/hr). Otherwise the
  unauthenticated client is used (60 req/hr per source IP).
  """
  def user(id, token \\ nil) do
    opts =
      if is_binary(token) and token != "", do: [headers: authorization_headers(token)], else: []

    case get("/user/" <> id, opts) do
      {:ok, res} ->
        cond do
          res.status in 200..299 ->
            {:ok,
             %{
               id: res.body["id"] |> Integer.to_string(),
               login: res.body["login"],
               name: res.body["name"]
             }}

          res.status == 404 ->
            Logger.debug("Error fetching user: #{inspect(res.body)}")

            {:error, :not_found}

          true ->
            Logger.debug("Error fetching user (HTTP #{res.status}): #{inspect(res.body)}")

            {:error, {:http, res.status}}
        end

      {:error, error} ->
        {:error, {:transport, error}}
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
      {:ok, true} -> {:ok, {repo_host_account.token, nil}}
      {:error, :transient} -> {:ok, {repo_host_account.token, nil}}
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

      {:ok, %Tesla.Env{status: status}} when status in [408, 429] ->
        Logger.warning("Transient failure refreshing github token (HTTP #{status})")
        {:error, :failed}

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

  def validate_token(""), do: {:ok, false}

  def validate_token(token) do
    case get("", headers: authorization_headers(token)) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, true}

      {:ok, %{status: 401}} ->
        {:ok, false}

      {:ok, %{status: status}} when status == 403 or status == 429 or status in 500..599 ->
        Logger.warning("Transient GitHub token validation failure (HTTP #{status})")
        {:error, :transient}

      {:ok, %{status: status, body: body}} ->
        Logger.warning(
          "Unexpected GitHub token validation response (HTTP #{status}): #{inspect(body)}"
        )

        {:error, :transient}

      {:error, error} ->
        Logger.error("Error validating GitHub token: #{inspect(error)}")
        {:error, :transient}
    end
  end

  defp authorization_headers(token) do
    [
      {"Authorization", "Bearer #{token}"}
    ]
  end
end
