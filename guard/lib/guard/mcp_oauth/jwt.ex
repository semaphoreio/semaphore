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
        "nbf" => now,
        "exp" => now + ttl,
        "jti" => Ecto.UUID.generate()
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
  Returns the default token TTL in seconds.
  """
  def default_token_ttl_seconds, do: @default_token_ttl_seconds

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
end
