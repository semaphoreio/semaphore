defmodule Guard.McpOAuth.Token do
  @moduledoc """
  OAuth 2.0 Token Endpoint for MCP OAuth.

  Handles token exchange - validates authorization codes and issues access tokens.
  """

  require Logger

  alias Guard.Repo
  alias Guard.Store.McpOAuthAuthCode
  alias Guard.McpOAuth.{Computers, JWT, PKCE}

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
    with :ok <- validate_grant_type(params) do
      exchange_in_transaction(params)
    end
  end

  defp exchange_in_transaction(params) do
    Repo.transaction(fn ->
      with {:ok, auth_code} <- lock_code(params),
           :ok <- validate_pkce(auth_code, params),
           :ok <- validate_redirect_uri(auth_code, params),
           {:ok, _} <- McpOAuthAuthCode.mark_code_used(auth_code),
           {:ok, response} <- issue(auth_code) do
        response
      else
        {:error, error_map} -> Repo.rollback(error_map)
      end
    end)
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

  # semaphore.computer's client gets a token for its API; every other client
  # gets an MCP token.
  defp issue(auth_code) do
    if Computers.client?(auth_code.client_id) do
      with {:ok, token} <- Computers.create_token(auth_code.user_id) do
        {:ok, build_response(token, Computers.ttl_seconds(), Computers.scope())}
      end
    else
      with {:ok, token} <- JWT.create_token(%{user_id: auth_code.user_id}) do
        {:ok, build_response(token, JWT.default_token_ttl_seconds(), "mcp")}
      end
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

  defp error_response(error, description) do
    %{
      "error" => error,
      "error_description" => description
    }
  end
end
