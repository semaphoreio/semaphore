defmodule Guard.McpOAuth.Revoke do
  @moduledoc """
  OAuth 2.0 Token Revocation (RFC 7009) for MCP OAuth refresh tokens.

  Revoking a refresh token revokes its family: every token rotated from the
  same authorization code. Access tokens are JWTs checked without asking
  guard, so they live until they expire.
  """

  require Logger

  alias Guard.McpOAuth.Computers
  alias Guard.Repo
  alias Guard.Store.McpOAuthRefreshToken

  @doc """
  Revokes a refresh token issued to the client. An unknown token, one already
  revoked, and one issued to another client are left as they are, and answered
  the same.

  ## Parameters
  - params: Map with revocation request parameters
    - token (required): The refresh token
    - token_type_hint (optional): Ignored, as only refresh tokens are revoked
    - client_id (required): Client identifier
    - client_secret: Required for semaphore.computer's client
  """
  @spec revoke(map()) :: :ok | {:error, 400 | 401, map()}
  def revoke(%{"token" => token, "client_id" => client_id} = params)
      when is_binary(token) and is_binary(client_id) do
    if Computers.client?(client_id) and not Computers.valid_secret?(params["client_secret"]) do
      {:error, 401, error_response("invalid_client", "Client authentication failed")}
    else
      {:ok, :ok} = Repo.transaction(fn -> revoke_family(token, client_id) end)
      :ok
    end
  end

  def revoke(_params),
    do: {:error, 400, error_response("invalid_request", "token and client_id are required")}

  # The family is locked, as a refresh locks it, so that a token rotated at
  # the same time is revoked too.
  defp revoke_family(token, client_id) do
    with {:ok, %{family: %{client_id: ^client_id, revoked_at: nil} = family}} <-
           McpOAuthRefreshToken.lock_by_token(token) do
      McpOAuthRefreshToken.revoke_family(family)

      Logger.info(
        "[McpOAuth.Revoke] Revoked refresh tokens: " <>
          "family=#{family.id} client=#{client_id} user=#{family.user_id}"
      )
    end

    :ok
  end

  defp error_response(error, description) do
    %{"error" => error, "error_description" => description}
  end
end
