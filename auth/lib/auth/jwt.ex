defmodule Auth.JWT do
  @moduledoc """
  JWT validation for MCP OAuth 2.1 tokens using Keycloak JWKS.

  This module validates JWT tokens issued by Keycloak for MCP server access.
  It verifies the token signature using JWKS, and validates standard claims
  including issuer, expiration, and the custom semaphore_user_id claim.
  """

  use Joken.Config
  require Logger

  # Add JokenJwks hook for automatic JWKS-based signature verification
  add_hook(JokenJwks, strategy: Auth.JWKSStrategy)

  @impl Joken.Config
  def token_config do
    domain = Application.fetch_env!(:auth, :domain)
    expected_audience = "https://mcp.#{domain}"
    expected_issuer = "https://id.#{domain}/realms/semaphore"

    default_claims(skip: [:aud, :iss])
    |> add_claim("aud", fn -> expected_audience end, &(&1 == expected_audience))
    |> add_claim("iss", fn -> expected_issuer end, &(&1 == expected_issuer))
  end

  @doc """
  Validates an MCP OAuth token and extracts the semaphore_user_id.

  Returns `{:ok, user_id, claims}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> Auth.JWT.validate_mcp_token("eyJhbGciOiJSUzI1NiIs...")
      {:ok, "user-uuid-here", %{"sub" => "...", "semaphore_user_id" => "user-uuid-here", ...}}

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
          {:ok, user_id, claims}

        _ ->
          Logger.warning("[Auth.JWT] Invalid semaphore_user_id claim type")
          {:error, :invalid_user_id}
      end
    end
  end

  defp verify_token(token) do
    # Use verify_and_validate which triggers the JokenJwks hook
    case __MODULE__.verify_and_validate(token) do
      {:ok, claims} ->
        validate_claims(claims)

      {:error, reason} ->
        Logger.warning("[Auth.JWT] Token verification failed: #{inspect(reason)}")
        {:error, :invalid_token}
    end
  end

  defp validate_claims(claims) do
    issuer = keycloak_issuer()
    now = DateTime.utc_now() |> DateTime.to_unix()

    with :ok <- validate_issuer(claims, issuer),
         :ok <- validate_expiration(claims, now),
         :ok <- validate_mcp_scope(claims) do
      {:ok, claims}
    end
  end

  defp validate_issuer(claims, expected_issuer) do
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

  defp keycloak_issuer do
    domain = Application.fetch_env!(:auth, :domain)
    "https://id.#{domain}/realms/semaphore"
  end
end
