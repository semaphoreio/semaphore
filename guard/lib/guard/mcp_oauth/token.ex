defmodule Guard.McpOAuth.Token do
  @moduledoc """
  OAuth 2.0 Token Endpoint for MCP OAuth.

  Handles token exchange for two grants:

  - `authorization_code` - validates the single-use code plus PKCE and issues an
    access token and a refresh token.
  - `refresh_token` - renews the access token without a browser round trip.

  Access tokens are deliberately short-lived, so a refresh grant is what keeps a
  client signed in; without it a client has to re-run the browser flow every
  time the access token expires. MCP clients are public clients, so refresh
  tokens are rotated on every use and replay of an already-used token revokes
  the whole token family.
  """

  require Logger

  alias Guard.Repo
  alias Guard.Store.{McpOAuthAuthCode, McpOAuthRefreshToken}
  alias Guard.McpOAuth.{JWT, PKCE}

  @doc """
  Exchanges an authorization code or a refresh token for an access token.

  ## Parameters
  - params: Map with token request parameters

  For `grant_type=authorization_code`:
    - code (required): Authorization code
    - redirect_uri (required): Must match the original request
    - client_id (required): Client identifier
    - code_verifier (required): PKCE verifier

  For `grant_type=refresh_token`:
    - refresh_token (required): Refresh token from a previous exchange
    - client_id (required): Must match the client the token was issued to

  ## Returns
  - `{:ok, token_response}` on success
  - `{:error, error_response}` on failure
  """
  @spec exchange(map()) :: {:ok, map()} | {:error, map()}
  def exchange(params) do
    case validate_grant_type(params) do
      {:ok, :authorization_code} -> exchange_code(params)
      {:ok, :refresh_token} -> exchange_refresh_token(params)
      {:error, error} -> {:error, error}
    end
  end

  # ====================
  # Authorization code grant
  # ====================

  defp exchange_code(params) do
    Repo.transaction(fn ->
      with {:ok, auth_code} <- lock_code(params),
           :ok <- validate_pkce(auth_code, params),
           :ok <- validate_redirect_uri(auth_code, params),
           {:ok, _} <- McpOAuthAuthCode.mark_code_used(auth_code),
           {:ok, response} <-
             issue_tokens(%{client_id: auth_code.client_id, user_id: auth_code.user_id}) do
        response
      else
        {:error, error_map} -> Repo.rollback(error_map)
      end
    end)
  end

  # ====================
  # Refresh token grant
  # ====================

  defp exchange_refresh_token(params) do
    case refresh_params(params) do
      {:ok, token, client_id} -> rotate_in_transaction(token, client_id)
      {:error, error} -> {:error, error}
    end
  end

  defp rotate_in_transaction(token, client_id) do
    result =
      Repo.transaction(fn ->
        case McpOAuthRefreshToken.lock_token(token, client_id) do
          {:ok, refresh_token} ->
            rotate(refresh_token)

          {:error, :not_found} ->
            Repo.rollback(error_response("invalid_grant", "Invalid refresh token"))
        end
      end)

    case result do
      # Replay detection has to commit the family revocation, so it reports the
      # failure as the transaction's value instead of rolling back.
      {:ok, {:error, error}} -> {:error, error}
      other -> other
    end
  end

  defp rotate(refresh_token) do
    cond do
      not is_nil(refresh_token.used_at) ->
        handle_replay(refresh_token)

      not is_nil(refresh_token.revoked_at) ->
        Repo.rollback(error_response("invalid_grant", "Refresh token has been revoked"))

      family_expired?(refresh_token) ->
        Repo.rollback(error_response("invalid_grant", "Refresh token family has expired"))

      expired?(refresh_token) ->
        Repo.rollback(error_response("invalid_grant", "Refresh token has expired"))

      true ->
        do_rotate(refresh_token)
    end
  end

  defp do_rotate(refresh_token) do
    attrs = Map.take(refresh_token, [:client_id, :user_id, :family_id, :family_expires_at])

    with {:ok, _} <- McpOAuthRefreshToken.mark_used(refresh_token),
         {:ok, response} <- issue_tokens(attrs) do
      response
    else
      {:error, error_map} -> Repo.rollback(error_map)
    end
  end

  # A used refresh token being presented again means either a leak or a client
  # that lost the rotated token. Neither is safe to serve, so the whole family
  # descending from the original grant is revoked and the user re-authorizes.
  defp handle_replay(refresh_token) do
    {count, _} = McpOAuthRefreshToken.revoke_family(refresh_token.family_id)

    Logger.warning(
      "[McpOAuth.Token] Refresh token replay detected for client=#{refresh_token.client_id}, " <>
        "revoked #{count} token(s) in family #{refresh_token.family_id}"
    )

    {:error, error_response("invalid_grant", "Refresh token has already been used")}
  end

  defp expired?(refresh_token),
    do: DateTime.compare(refresh_token.expires_at, DateTime.utc_now()) != :gt

  # Rotation carries the family deadline over untouched, so a family that keeps
  # refreshing still ages out. Belt and braces: `issue/1` caps a token's own
  # expiry at that deadline, so a rotated token normally expires with it.
  defp family_expired?(refresh_token),
    do: DateTime.compare(refresh_token.family_expires_at, DateTime.utc_now()) != :gt

  defp refresh_params(params) do
    cond do
      not is_binary(params["refresh_token"]) ->
        {:error, error_response("invalid_request", "refresh_token is required")}

      not is_binary(params["client_id"]) ->
        {:error, error_response("invalid_request", "client_id is required")}

      true ->
        {:ok, params["refresh_token"], params["client_id"]}
    end
  end

  # ====================
  # Shared
  # ====================

  defp validate_grant_type(params) do
    case params["grant_type"] do
      "authorization_code" ->
        {:ok, :authorization_code}

      "refresh_token" ->
        {:ok, :refresh_token}

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

  # Mints the access token and the refresh token that replaces the credential
  # just consumed. A fresh authorization passes only client_id/user_id and so
  # starts a new family; rotation also passes the family and its deadline.
  defp issue_tokens(attrs) do
    with {:ok, access_token} <- JWT.create_token(%{user_id: attrs.user_id}),
         {:ok, refresh_token, _record} <- McpOAuthRefreshToken.issue(attrs) do
      {:ok, build_response(access_token, refresh_token)}
    else
      {:error, reason} ->
        Logger.error("[McpOAuth.Token] Failed to issue tokens: #{inspect(reason)}")
        {:error, error_response("server_error", "Failed to issue tokens")}
    end
  end

  defp build_response(access_token, refresh_token) do
    %{
      "access_token" => access_token,
      "token_type" => "Bearer",
      "expires_in" => JWT.default_token_ttl_seconds(),
      "refresh_token" => refresh_token,
      "scope" => "mcp"
    }
  end

  defp error_response(error, description) do
    %{
      "error" => error,
      "error_description" => description
    }
  end
end
