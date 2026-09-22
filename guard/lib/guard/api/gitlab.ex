defmodule Guard.Api.Gitlab do
  require Logger

  alias Guard.Utils.OAuth

  @base_url "https://gitlab.com"
  @oauth_path "/oauth/token"
  @oauth_token_info_path "#{@oauth_path}/info"

  @doc """
  Fetch or refresh access token
  """
  def user_token(repo_host_account) do
    if OAuth.valid_token?(repo_host_account.token_expires_at, nil_valid: false) do
      {:ok, {repo_host_account.token, repo_host_account.token_expires_at}}
    else
      handle_fetch_token(repo_host_account)
    end
  end

  def validate_token(token) do
    client = build_validate_token_client(token)

    case Tesla.get(client, @oauth_token_info_path) do
      {:ok, res} ->
        expires_at = OAuth.calc_expires_at(res.body["expires_in"])
        {:ok, res.status in 200..299 && OAuth.valid_token?(expires_at, nil_valid: false)}

      {:error, error} ->
        Logger.error("Error validating token: #{inspect(error)}")
        {:error, :network_error}
    end
  end

  defp handle_fetch_token(%{refresh_token: refresh_token}) when refresh_token in [nil, ""] do
    Logger.warning("No refresh token found for GitLab repo host account, account is revoked")
    {:error, :revoked}
  end

  defp handle_fetch_token(repo_host_account) do
    body_params = %{
      "grant_type" => "refresh_token",
      "refresh_token" => repo_host_account.refresh_token,
      "scope" => gitlab_scope()
    }

    client = build_token_client()

    case Tesla.post(client, @oauth_path, body_params) do
      {:ok, %Tesla.Env{status: status, body: body}} when status in 200..299 ->
        OAuth.handle_ok_token_response(repo_host_account, body)

      {:ok, %Tesla.Env{status: status, body: body}} ->
        case OAuth.classify_refresh_response(status, body) do
          :revoked ->
            Logger.warning(
              "Failed to refresh GitLab token (HTTP #{status}): " <>
                "error=#{inspect(safe_oauth_error(body))} " <>
                "rha=#{repo_host_account.id} user=#{repo_host_account.user_id}"
            )

            {:error, :revoked}

          :transient ->
            Logger.warning(
              "Transient failure refreshing GitLab token (HTTP #{status}): " <>
                "error=#{inspect(safe_oauth_error(body))} " <>
                "rha=#{repo_host_account.id} user=#{repo_host_account.user_id}"
            )

            {:error, :transient}
        end

      {:error, error} ->
        Logger.error(
          "Error fetching GitLab token: #{inspect(error)} " <>
            "rha=#{repo_host_account.id} user=#{repo_host_account.user_id}"
        )

        {:error, :network_error}
    end
  end

  # Never log the raw body (it can carry token material); surface only the
  # OAuth `error` code.
  defp safe_oauth_error(body) when is_map(body), do: Map.get(body, "error")

  defp safe_oauth_error(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> safe_oauth_error(decoded)
      _ -> nil
    end
  end

  defp safe_oauth_error(_), do: nil

  # Hard bound on the refresh POST: it runs while holding a Postgres advisory
  # lock and a pooled Front-DB connection (see the single-flight in
  # Guard.FrontRepo.RepoHostAccount), so a hung provider must not be able to
  # park either one until the caller's RPC deadline.
  @refresh_timeout_ms 3_000

  defp build_token_client do
    {:ok, {client_id, client_secret}} = Guard.GitProviderCredentials.get(:gitlab)

    Tesla.client([
      {Tesla.Middleware.Timeout, timeout: @refresh_timeout_ms},
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
end
