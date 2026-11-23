defmodule Guard.McpOAuth.Token do
  @moduledoc """
  OAuth 2.0 Token Endpoint for MCP OAuth.

  Exchanges authorization codes and refresh tokens for access tokens. A refresh
  token rotates on every use, which leaves only the new token live; reusing an
  older one after a short grace period revokes every token rotated from the same
  authorization code.
  """

  require Logger

  alias Guard.{FrontRepo, Repo}
  alias Guard.Store.{McpOAuthAuthCode, McpOAuthRefreshToken}
  alias Guard.McpOAuth.{Computers, JWT, PKCE}

  @grant_types ["authorization_code", "refresh_token"]

  @doc """
  Exchanges an authorization code or a refresh token for an access token and a
  new refresh token.

  ## Parameters
  - params: Map with token request parameters
    - grant_type (required): "authorization_code" or "refresh_token"
    - client_id (required): Client identifier
    - client_secret: Required for semaphore.computer's client
    - code (required for authorization_code): Authorization code
    - redirect_uri (required for authorization_code): Must match the original request
    - code_verifier (required for authorization_code): PKCE verifier
    - refresh_token (required for refresh_token): Refresh token
    - scope (optional for refresh_token): Must be the scope originally granted
    - resource (optional for authorization_code): Must be the one authorized

  ## Returns
  - `{:ok, token_response}` on success
  - `{:error, error_response}` on failure
  """
  @spec exchange(map()) :: {:ok, map()} | {:error, map()}
  def exchange(params) do
    with :ok <- validate_grant_type(params),
         :ok <- authenticate_client(params) do
      case params["grant_type"] do
        "authorization_code" -> exchange_code(params)
        "refresh_token" -> refresh(params)
      end
    end
  end

  defp exchange_code(params) do
    Repo.transaction(fn ->
      with {:ok, auth_code} <- lock_code(params),
           :ok <- validate_pkce(auth_code, params),
           :ok <- validate_redirect_uri(auth_code, params),
           :ok <- validate_resource(auth_code, params),
           {:ok, _} <- McpOAuthAuthCode.mark_code_used(auth_code),
           scope = scope(auth_code.client_id, auth_code.resource),
           {:ok, response} <- issue(auth_code.user_id, scope, auth_code.resource) do
        refresh_token =
          McpOAuthRefreshToken.create(
            auth_code.client_id,
            auth_code.user_id,
            scope,
            auth_code.resource
          )

        Map.put(response, "refresh_token", refresh_token)
      else
        {:error, error_map} -> Repo.rollback(error_map)
      end
    end)
  end

  # Never rolled back, so that a family revoked by a failing request stays revoked.
  defp refresh(params) do
    with {:ok, token, client_id} <- refresh_params(params),
         {:ok, result} <- Repo.transaction(fn -> rotate(token, client_id, params["scope"]) end) do
      result
    end
  end

  defp rotate(token, client_id, scope) do
    with {:ok, refresh_token} <- lock_refresh_token(token),
         family = refresh_token.family,
         :ok <- validate_client(family, client_id),
         :ok <- validate_live(refresh_token),
         :ok <- validate_reuse(refresh_token),
         :ok <- validate_scope(family, scope),
         :ok <- validate_user(family),
         {:ok, response} <- issue(family.user_id, family.scope, family.resource) do
      {:ok, Map.put(response, "refresh_token", McpOAuthRefreshToken.rotate(refresh_token))}
    end
  end

  # Private functions

  defp validate_grant_type(params) do
    case params["grant_type"] do
      grant_type when grant_type in @grant_types ->
        :ok

      nil ->
        {:error, error_response("invalid_request", "grant_type is required")}

      other ->
        {:error,
         error_response(
           "unsupported_grant_type",
           "grant_type must be 'authorization_code' or 'refresh_token', got '#{other}'"
         )}
    end
  end

  defp authenticate_client(params) do
    if Computers.client?(params["client_id"]) and
         not Computers.valid_secret?(params["client_secret"]) do
      {:error, error_response("invalid_client", "Client authentication failed")}
    else
      :ok
    end
  end

  defp lock_code(params) do
    code = params["code"]
    client_id = params["client_id"]

    cond do
      is_nil(code) ->
        {:error, error_response("invalid_request", "code is required")}

      is_nil(client_id) ->
        {:error, error_response("invalid_request", "client_id is required")}

      true ->
        case McpOAuthAuthCode.lock_code(code, client_id) do
          {:ok, auth_code} ->
            {:ok, auth_code}

          {:error, :invalid_or_used} ->
            {:error,
             error_response(
               "invalid_grant",
               "Invalid, expired, or already used authorization code"
             )}
        end
    end
  end

  defp validate_pkce(auth_code, params) do
    case params["code_verifier"] do
      nil ->
        {:error, error_response("invalid_request", "code_verifier is required")}

      code_verifier ->
        if PKCE.verify(code_verifier, auth_code.code_challenge) do
          :ok
        else
          {:error, error_response("invalid_grant", "Invalid code_verifier")}
        end
    end
  end

  defp validate_redirect_uri(auth_code, params) do
    case params["redirect_uri"] do
      nil ->
        {:error, error_response("invalid_request", "redirect_uri is required")}

      redirect_uri ->
        if redirect_uri == auth_code.redirect_uri do
          :ok
        else
          {:error, error_response("invalid_grant", "redirect_uri does not match")}
        end
    end
  end

  # A code for one of semaphore.computer's MCP servers is for that server
  # alone (RFC 8707). Any other code was issued as before resource was read.
  defp validate_resource(%{resource: nil}, _params), do: :ok

  defp validate_resource(%{resource: resource}, params) do
    if params["resource"] in [nil, resource] do
      :ok
    else
      {:error, error_response("invalid_target", "resource must be the one authorized")}
    end
  end

  defp refresh_params(%{"refresh_token" => token, "client_id" => client_id})
       when is_binary(token) and is_binary(client_id),
       do: {:ok, token, client_id}

  defp refresh_params(_params),
    do: {:error, error_response("invalid_request", "refresh_token and client_id are required")}

  defp lock_refresh_token(token) do
    case McpOAuthRefreshToken.lock_by_token(token) do
      {:ok, refresh_token} -> {:ok, refresh_token}
      {:error, :not_found} -> {:error, invalid_refresh_token()}
    end
  end

  # The scope check refuses a Computers family whose client is no longer the
  # configured one, as authenticate_client/1 did not authenticate it, and one
  # for an MCP server no longer configured.
  defp validate_client(family, client_id) do
    if family.client_id == client_id and family.scope == scope(client_id, family.resource) do
      :ok
    else
      {:error, invalid_refresh_token()}
    end
  end

  defp validate_live(%{family: family} = refresh_token) do
    now = DateTime.utc_now()

    if is_nil(family.revoked_at) and DateTime.compare(refresh_token.expires_at, now) == :gt and
         DateTime.compare(family.expires_at, now) == :gt do
      :ok
    else
      {:error, invalid_refresh_token()}
    end
  end

  defp validate_reuse(%{used_at: nil}), do: :ok

  defp validate_reuse(%{used_at: used_at, family: family}) do
    grace_seconds = Application.fetch_env!(:guard, :mcp_oauth_refresh_token_reuse_grace_seconds)

    if DateTime.diff(DateTime.utc_now(), used_at) <= grace_seconds do
      :ok
    else
      revoke(family, "a rotated refresh token was reused")
    end
  end

  defp validate_scope(_family, nil), do: :ok
  defp validate_scope(%{scope: scope}, scope), do: :ok

  defp validate_scope(_family, _scope),
    do: {:error, error_response("invalid_scope", "scope must be the one originally granted")}

  defp validate_user(family) do
    case FrontRepo.User.active_user_by_id(family.user_id) do
      {:ok, _user} -> :ok
      {:error, :not_found} -> revoke(family, "the user is blocked or deactivated")
    end
  end

  defp revoke(family, reason) do
    McpOAuthRefreshToken.revoke_family(family)

    Logger.warning(
      "[McpOAuth.Token] Revoked refresh tokens, #{reason}: " <>
        "family=#{family.id} client=#{family.client_id} user=#{family.user_id}"
    )

    {:error, invalid_refresh_token()}
  end

  defp scope(client_id, resource) do
    if Computers.client?(client_id) or Computers.mcp_resource?(resource),
      do: Computers.scope(),
      else: "mcp"
  end

  defp issue(user_id, "computers" = scope, resource) do
    with {:ok, token} <- Computers.create_token(user_id, resource) do
      {:ok, build_response(token, Computers.ttl_seconds(), scope)}
    end
  end

  defp issue(user_id, "mcp" = scope, _resource) do
    with {:ok, token} <- JWT.create_token(%{user_id: user_id}) do
      {:ok, build_response(token, JWT.default_token_ttl_seconds(), scope)}
    end
  end

  defp build_response(token, ttl_seconds, scope) do
    %{
      "access_token" => token,
      "token_type" => "Bearer",
      "expires_in" => ttl_seconds,
      "scope" => scope
    }
  end

  defp invalid_refresh_token,
    do: error_response("invalid_grant", "Invalid, expired, or revoked refresh token")

  defp error_response(error, description) do
    %{
      "error" => error,
      "error_description" => description
    }
  end
end
