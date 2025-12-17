defmodule Auth.JWKSStrategy do
  @moduledoc """
  JWKS strategy for fetching Keycloak signing keys.

  This module implements the JokenJwks.DefaultStrategyTemplate to fetch
  and cache JWKS from Keycloak for JWT verification.
  """

  use JokenJwks.DefaultStrategyTemplate

  def init_opts(_opts) do
    domain = Application.fetch_env!(:auth, :domain)
    jwks_url = "https://id.#{domain}/realms/semaphore/protocol/openid-connect/certs"

    [
      jwks_url: jwks_url,
      first_fetch_sync: true,
      http_max_retries_per_fetch: 3,
      should_start: true
    ]
  end
end
