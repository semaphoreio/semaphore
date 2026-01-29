defmodule Guard.McpOAuth.Token do
  @moduledoc """
  OAuth 2.0 Token Endpoint for MCP OAuth.

  Handles token exchange - validates authorization codes and issues access tokens.
  """

  require Logger

  alias Guard.Store.McpOAuthAuthCode
  alias Guard.McpOAuth.{JWT, PKCE}

  @doc """
  Exchanges an authorization code for an access token.

  ## Parameters
  - params: Map with token request parameters
    - grant_type (required): Must be "authorization_code"
    - code (required): Authorization code
    - redirect_uri (required): Must match the original request
    - client_id (required): Client identifier
    - code_verifier (required): PKCE verifier

  ## Returns
  - `{:ok, token_response}` on success
  - `{:error, error_response}` on failure
  """
  @spec exchange(map()) :: {:ok, map()} | {:error, map()}
  def exchange(params) do
    with :ok <- validate_grant_type(params),
         {:ok, auth_code} <- validate_and_consume_code(params),
         :ok <- validate_pkce(auth_code, params),
         :ok <- validate_redirect_uri(auth_code, params),
         {:ok, token} <- create_token(auth_code) do
      {:ok, build_response(token)}
    end
  end

  # Private functions

  defp validate_grant_type(params) do
    case params["grant_type"] do
      "authorization_code" ->
        :ok

      nil ->
        {:error, error_response("invalid_request", "grant_type is required")}

      other ->
        {:error,
         error_response(
           "unsupported_grant_type",
           "grant_type must be 'authorization_code', got '#{other}'"
         )}
    end
  end

  defp validate_and_consume_code(params) do
    code = params["code"]
    client_id = params["client_id"]

    cond do
      is_nil(code) ->
        {:error, error_response("invalid_request", "code is required")}

      is_nil(client_id) ->
        {:error, error_response("invalid_request", "client_id is required")}

      true ->
        case McpOAuthAuthCode.find_by_code(code) do
          {:ok, auth_code} ->
            if auth_code.client_id == client_id do
              # Mark code as used (single-use)
              case McpOAuthAuthCode.mark_used(auth_code) do
                {:ok, _} -> {:ok, auth_code}
                {:error, _} -> {:error, error_response("server_error", "Failed to process code")}
              end
            else
              {:error, error_response("invalid_grant", "Code was not issued to this client")}
            end

          {:error, :not_found} ->
            {:error, error_response("invalid_grant", "Invalid authorization code")}

          {:error, :expired} ->
            {:error, error_response("invalid_grant", "Authorization code has expired")}

          {:error, :used} ->
            Logger.warning("[McpOAuth.Token] Attempted reuse of authorization code")
            {:error, error_response("invalid_grant", "Authorization code has already been used")}
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

  defp create_token(auth_code) do
    JWT.create_token(%{user_id: auth_code.user_id})
  end

  defp build_response(token) do
    %{
      "access_token" => token,
      "token_type" => "Bearer",
      "expires_in" => 3600,
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
