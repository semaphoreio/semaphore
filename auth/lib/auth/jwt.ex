defmodule Auth.JWT do
  @moduledoc """
  JWT validation for MCP OAuth tokens using HS256 shared secret.

  This module validates JWT tokens issued by Guard for MCP server access.
  It verifies the token signature using a shared secret (HS256), and validates
  standard claims including issuer, audience, expiration, and the custom
  semaphore_user_id claim.

  The signing keys are read from MCP_OAUTH_JWT_KEYS environment variable,
  which supports comma-separated keys for rotation.
  """

  require Logger

  @doc """
  Validates an MCP OAuth token and extracts the semaphore_user_id.

  Returns `{:ok, user_id, grant_id, tool_scopes, claims}` on success,
  or `{:error, reason}` on failure.

  ## Examples

      iex> Auth.JWT.validate_mcp_token("eyJhbGciOiJIUzI1NiIs...")
      {:ok, "user-uuid-here", "grant-uuid", ["tools:read"], %{...}}

      iex> Auth.JWT.validate_mcp_token("invalid-token")
      {:error, :invalid_token}
  """
  def validate_mcp_token(token) do
    with {:ok, claims} <- verify_token(token) do
      case Map.get(claims, "semaphore_user_id") do
        nil ->
          Logger.warning("[Auth.JWT] Token missing semaphore_user_id claim")
          {:error, :missing_user_id}

        user_id when is_binary(user_id) ->
          # Extract MCP-specific claims
          grant_id = Map.get(claims, "mcp_grant_id", "")
          tool_scopes = Map.get(claims, "mcp_tool_scopes", [])

          {:ok, user_id, grant_id, tool_scopes, claims}

        _ ->
          Logger.warning("[Auth.JWT] Invalid semaphore_user_id claim type")
          {:error, :invalid_user_id}
      end
    end
  end

  defp verify_token(token) do
    case get_all_signers() do
      {:ok, signers} ->
        # Try each signer (supports key rotation)
        result =
          Enum.reduce_while(signers, {:error, :invalid_signature}, fn signer, _acc ->
            case Joken.verify(token, signer) do
              {:ok, claims} ->
                {:halt, {:ok, claims}}

              {:error, _reason} ->
                {:cont, {:error, :invalid_signature}}
            end
          end)

        case result do
          {:ok, claims} -> validate_claims(claims)
          error -> error
        end

      {:error, :no_signing_key} ->
        Logger.error("[Auth.JWT] No signing keys configured")
        {:error, :configuration_error}
    end
  end

  defp validate_claims(claims) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    with :ok <- validate_issuer(claims),
         :ok <- validate_audience(claims),
         :ok <- validate_expiration(claims, now),
         :ok <- validate_mcp_scope(claims) do
      {:ok, claims}
    end
  end

  defp validate_issuer(claims) do
    expected_issuer = oauth_issuer()

    case Map.get(claims, "iss") do
      ^expected_issuer ->
        :ok

      actual_issuer ->
        Logger.warning(
          "[Auth.JWT] Invalid issuer: expected #{expected_issuer}, got #{inspect(actual_issuer)}"
        )

        {:error, :invalid_issuer}
    end
  end

  defp validate_audience(claims) do
    expected_audience = oauth_audience()

    case Map.get(claims, "aud") do
      ^expected_audience ->
        :ok

      actual_audience ->
        Logger.warning(
          "[Auth.JWT] Invalid audience: expected #{expected_audience}, got #{inspect(actual_audience)}"
        )

        {:error, :invalid_audience}
    end
  end

  defp validate_expiration(claims, now) do
    # Allow 60 seconds clock skew
    clock_skew = 60

    case Map.get(claims, "exp") do
      exp when is_number(exp) and exp + clock_skew > now ->
        :ok

      exp when is_number(exp) ->
        Logger.warning("[Auth.JWT] Token expired at #{exp}, current time #{now}")
        {:error, :token_expired}

      _ ->
        Logger.warning("[Auth.JWT] Token missing exp claim")
        {:error, :missing_exp}
    end
  end

  defp validate_mcp_scope(claims) do
    scope = Map.get(claims, "scope", "")

    if String.contains?(scope, "mcp") do
      :ok
    else
      Logger.warning("[Auth.JWT] Token missing mcp scope: #{inspect(scope)}")
      {:error, :invalid_scope}
    end
  end

  defp oauth_issuer do
    domain = Application.fetch_env!(:auth, :domain)
    "https://mcp.#{domain}/mcp/oauth"
  end

  defp oauth_audience do
    domain = Application.fetch_env!(:auth, :domain)
    "https://mcp.#{domain}"
  end

  defp get_all_signers do
    case get_signing_keys() do
      [] -> {:error, :no_signing_key}
      keys -> {:ok, Enum.map(keys, &Joken.Signer.create("HS256", &1))}
    end
  end

  defp get_signing_keys do
    case System.get_env("MCP_OAUTH_JWT_KEYS") do
      nil ->
        Logger.warning("[Auth.JWT] MCP_OAUTH_JWT_KEYS not set")
        []

      "" ->
        Logger.warning("[Auth.JWT] MCP_OAUTH_JWT_KEYS is empty")
        []

      keys_string ->
        keys_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
    end
  end
end
