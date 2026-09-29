defmodule Guard.McpOAuth.Computers do
  @moduledoc """
  semaphore.computer's web UI, as a first-party client of this OAuth server.

  People sign in to semaphore.computer with their Semaphore account. Its client
  is configured rather than registered, and it is trusted: nobody is asked to
  consent to it, since they are signing in with their own account.

  Its access tokens are for semaphore.computer's API, which does not hold the
  MCP signing secret. They are RS256 JWTs, and the API checks them against the
  public key this server publishes at `/jwks`:
  - iss: the OAuth issuer, as for MCP tokens
  - aud: COMPUTERS_OAUTH_AUDIENCE
  - sub, semaphore_user_id: the user
  - scope: "computers"

  Configured by COMPUTERS_OAUTH_CLIENT_ID, COMPUTERS_OAUTH_REDIRECT_URIS
  (comma-separated), COMPUTERS_OAUTH_AUDIENCE and COMPUTERS_OAUTH_SIGNING_KEY
  (a PEM RSA private key; `\\n` stands for a newline). Without all four there is
  no such client. COMPUTERS_OAUTH_ACCESS_TOKEN_TTL_SECONDS is 3600 by default.
  """

  require Logger

  alias Guard.McpOAuth.JWT
  alias Guard.Repo.McpOAuthClient

  @scope "computers"
  @client_name "Semaphore Computer"
  @default_ttl_seconds 3600

  def scope, do: @scope

  @doc "The configured client, or nil when there is none."
  @spec client() :: McpOAuthClient.t() | nil
  def client do
    case config() do
      {:ok, config} ->
        %McpOAuthClient{
          client_id: config.client_id,
          client_name: @client_name,
          redirect_uris: config.redirect_uris
        }

      :error ->
        nil
    end
  end

  @spec client?(String.t() | nil) :: boolean()
  def client?(client_id) when is_binary(client_id) do
    case client() do
      %McpOAuthClient{client_id: ^client_id} -> true
      _ -> false
    end
  end

  def client?(_), do: false

  @spec ttl_seconds() :: pos_integer()
  def ttl_seconds do
    case Integer.parse(System.get_env("COMPUTERS_OAUTH_ACCESS_TOKEN_TTL_SECONDS") || "") do
      {ttl, ""} when ttl > 0 -> ttl
      _ -> @default_ttl_seconds
    end
  end

  @doc "An access token for semaphore.computer's API, issued to user_id."
  @spec create_token(String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_token(user_id) do
    with {:ok, config} <- config() do
      now = DateTime.utc_now() |> DateTime.to_unix()

      claims = %{
        "iss" => JWT.issuer(),
        "aud" => config.audience,
        "sub" => user_id,
        "semaphore_user_id" => user_id,
        "scope" => @scope,
        "iat" => now,
        "nbf" => now,
        "exp" => now + ttl_seconds(),
        "jti" => Ecto.UUID.generate()
      }

      signer =
        Joken.Signer.create("RS256", %{"pem" => config.signing_key}, %{"kid" => kid(config)})

      {:ok, Joken.generate_and_sign!(%{}, claims, signer)}
    else
      :error -> {:error, :no_computers_client}
    end
  rescue
    e ->
      Logger.error("[McpOAuth.Computers] Error creating token: #{inspect(e)}")
      {:error, :token_creation_failed}
  end

  @doc "The public keys the access tokens are signed with, as JWKs."
  @spec jwks() :: [map()]
  def jwks do
    case config() do
      {:ok, config} ->
        {_, public} =
          config.signing_key |> JOSE.JWK.from_pem() |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()

        [Map.merge(public, %{"kid" => kid(config), "use" => "sig", "alg" => "RS256"})]

      :error ->
        []
    end
  rescue
    e ->
      Logger.error("[McpOAuth.Computers] Error reading the signing key: #{inspect(e)}")
      []
  end

  # The key's RFC 7638 thumbprint: a new key gets a new id.
  defp kid(config) do
    config.signing_key |> JOSE.JWK.from_pem() |> JOSE.JWK.thumbprint()
  end

  defp config do
    client_id = System.get_env("COMPUTERS_OAUTH_CLIENT_ID") || ""
    audience = System.get_env("COMPUTERS_OAUTH_AUDIENCE") || ""

    signing_key =
      (System.get_env("COMPUTERS_OAUTH_SIGNING_KEY") || "") |> String.replace("\\n", "\n")

    redirect_uris =
      (System.get_env("COMPUTERS_OAUTH_REDIRECT_URIS") || "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if Enum.any?([client_id, audience, signing_key], &(&1 == "")) or redirect_uris == [] do
      :error
    else
      {:ok,
       %{
         client_id: client_id,
         audience: audience,
         signing_key: signing_key,
         redirect_uris: redirect_uris
       }}
    end
  end
end
