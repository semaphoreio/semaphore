defmodule Guard.McpOAuth.JWT do
  @moduledoc """
  JWT minting for MCP OAuth tokens using HS256.

  Creates access tokens with the following claims:
  - iss: OAuth issuer (https://mcp.{domain}/mcp/oauth)
  - aud: Resource server (https://mcp.{domain})
  - sub: User ID
  - semaphore_user_id: Semaphore user UUID
  - scope: "mcp"
  - exp: Expiration time
  - iat: Issued at time

  The signing key is read from MCP_OAUTH_JWT_KEYS environment variable,
  which supports comma-separated keys for rotation (first key used for signing).
  """

  require Logger

  @default_token_ttl_seconds 3600

  @doc """
  Creates a signed JWT for an MCP grant.

  ## Options
  - `:ttl_seconds` - Token TTL in seconds (default: 3600)

  ## Returns
  - `{:ok, token}` on success
  - `{:error, reason}` on failure
  """
  @spec create_token(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def create_token(params, opts \\ []) do
    with {:ok, signer} <- get_signer() do
      now = DateTime.utc_now() |> DateTime.to_unix()
      ttl = Keyword.get(opts, :ttl_seconds, @default_token_ttl_seconds)

      claims = %{
        "iss" => issuer(),
        "aud" => audience(),
        "sub" => params.user_id,
        "semaphore_user_id" => params.user_id,
        "scope" => "mcp",
        "iat" => now,
        "exp" => now + ttl
      }

      token = Joken.generate_and_sign!(%{}, claims, signer)
      {:ok, token}
    end
  rescue
    e ->
      Logger.error("[McpOAuth.JWT] Error creating token: #{inspect(e)}")
      {:error, :token_creation_failed}
  end

  @doc """
  Validates a JWT token.

  Used for local validation (e.g., in tests or internal services).
  The Auth service uses its own validation module.

  ## Returns
  - `{:ok, claims}` on success
  - `{:error, reason}` on failure
  """
  @spec validate_token(String.t()) :: {:ok, map()} | {:error, term()}
  def validate_token(token) do
    with {:ok, signers} <- get_all_signers() do
      # Try each signer (supports key rotation)
      Enum.reduce_while(signers, {:error, :invalid_signature}, fn signer, _acc ->
        case Joken.verify(token, signer) do
          {:ok, claims} ->
            case validate_claims(claims) do
              :ok -> {:halt, {:ok, claims}}
              error -> {:halt, error}
            end

          {:error, _reason} ->
            {:cont, {:error, :invalid_signature}}
        end
      end)
    end
  end

  @doc """
  Returns the OAuth issuer URL.
  """
  @spec issuer() :: String.t()
  def issuer do
    domain = Application.fetch_env!(:guard, :base_domain)
    "https://mcp.#{domain}/mcp/oauth"
  end

  @doc """
  Returns the OAuth audience URL.
  """
  @spec audience() :: String.t()
  def audience do
    domain = Application.fetch_env!(:guard, :base_domain)
    "https://mcp.#{domain}"
  end

  # Private functions

  defp get_signer do
    case get_signing_keys() do
      [key | _] -> {:ok, Joken.Signer.create("HS256", key)}
      [] -> {:error, :no_signing_key}
    end
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
        Logger.warning("[McpOAuth.JWT] MCP_OAUTH_JWT_KEYS not set")
        []

      "" ->
        Logger.warning("[McpOAuth.JWT] MCP_OAUTH_JWT_KEYS is empty")
        []

      keys_string ->
        keys_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
    end
  end

  defp validate_claims(claims) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    clock_skew = 60

    with :ok <- validate_expiration(claims, now, clock_skew),
         :ok <- validate_issuer(claims),
         :ok <- validate_audience(claims) do
      :ok
    end
  end

  defp validate_expiration(claims, now, clock_skew) do
    case Map.get(claims, "exp") do
      exp when is_number(exp) and exp + clock_skew > now ->
        :ok

      exp when is_number(exp) ->
        Logger.warning("[McpOAuth.JWT] Token expired at #{exp}, current time #{now}")
        {:error, :token_expired}

      _ ->
        Logger.warning("[McpOAuth.JWT] Token missing exp claim")
        {:error, :missing_exp}
    end
  end

  defp validate_issuer(claims) do
    expected = issuer()

    case Map.get(claims, "iss") do
      ^expected -> :ok
      actual ->
        Logger.warning("[McpOAuth.JWT] Invalid issuer: expected #{expected}, got #{inspect(actual)}")
        {:error, :invalid_issuer}
    end
  end

  defp validate_audience(claims) do
    expected = audience()

    case Map.get(claims, "aud") do
      ^expected -> :ok
      actual ->
        Logger.warning("[McpOAuth.JWT] Invalid audience: expected #{expected}, got #{inspect(actual)}")
        {:error, :invalid_audience}
    end
  end
end
