defmodule Guard.McpOAuth.Computers do
  @moduledoc """
  semaphore.computer's web UI, as a first-party OAuth client: configured rather
  than registered, confidential, and not asked for consent.

  Its access tokens are RS256 JWTs for semaphore.computer's API, which checks
  them against the public key published at `/jwks`:
  - iss: the OAuth issuer, as for MCP tokens
  - aud: COMPUTERS_OAUTH_AUDIENCE
  - sub, semaphore_user_id: the user
  - scope: "computers"

  Configured by COMPUTERS_OAUTH_CLIENT_ID, COMPUTERS_OAUTH_CLIENT_SECRET,
  COMPUTERS_OAUTH_REDIRECT_URIS (comma-separated), COMPUTERS_OAUTH_AUDIENCE and
  COMPUTERS_OAUTH_SIGNING_KEY (a PEM RSA private key; `\\n` stands for a
  newline). Without all five, or with a key that is not an RSA private key,
  there is no such client. COMPUTERS_OAUTH_ACCESS_TOKEN_TTL_SECONDS is 3600 by
  default.
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

  @spec valid_secret?(String.t() | nil) :: boolean()
  def valid_secret?(client_secret) when is_binary(client_secret) do
    case config() do
      {:ok, config} -> Plug.Crypto.secure_compare(client_secret, config.client_secret)
      :error -> false
    end
  end

  def valid_secret?(_), do: false

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
    case config() do
      {:ok, config} ->
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

        {_, key} = JOSE.JWK.to_map(config.signing_key)
        signer = Joken.Signer.create("RS256", key, %{"kid" => config.kid})

        {:ok, Joken.generate_and_sign!(%{}, claims, signer)}

      :error ->
        {:error, :no_computers_client}
    end
  rescue
    e ->
      Logger.error("[McpOAuth.Computers] Error creating token: #{inspect(e.__struct__)}")
      {:error, :token_creation_failed}
  end

  @doc "The public keys the access tokens are signed with, as JWKs."
  @spec jwks() :: [map()]
  def jwks do
    case config() do
      {:ok, config} ->
        {_, public} = config.signing_key |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()

        [Map.merge(public, %{"kid" => config.kid, "use" => "sig", "alg" => "RS256"})]

      :error ->
        []
    end
  end

  defp config do
    client_id = env("COMPUTERS_OAUTH_CLIENT_ID")
    client_secret = env("COMPUTERS_OAUTH_CLIENT_SECRET")
    audience = env("COMPUTERS_OAUTH_AUDIENCE")

    redirect_uris =
      env("COMPUTERS_OAUTH_REDIRECT_URIS")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    with false <- Enum.any?([client_id, client_secret, audience], &(&1 == "")),
         false <- redirect_uris == [],
         {:ok, signing_key} <- signing_key(env("COMPUTERS_OAUTH_SIGNING_KEY")) do
      {:ok,
       %{
         client_id: client_id,
         client_secret: client_secret,
         audience: audience,
         redirect_uris: redirect_uris,
         signing_key: signing_key,
         kid: JOSE.JWK.thumbprint(signing_key)
       }}
    else
      _ -> :error
    end
  end

  defp env(name), do: System.get_env(name) || ""

  defp signing_key(""), do: :error

  defp signing_key(pem) do
    case pem |> String.replace("\\n", "\n") |> JOSE.JWK.from_pem() do
      %JOSE.JWK{kty: {:jose_jwk_kty_rsa, key}} = jwk when elem(key, 0) == :RSAPrivateKey ->
        {:ok, jwk}

      _ ->
        invalid_signing_key()
    end
  rescue
    _ -> invalid_signing_key()
  end

  defp invalid_signing_key do
    Logger.error("[McpOAuth.Computers] COMPUTERS_OAUTH_SIGNING_KEY is not an RSA private key")
    :error
  end
end
