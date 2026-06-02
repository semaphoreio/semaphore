defmodule Secrethub.OpenIDConnect.HTTPServer do
  require Logger
  use Plug.Router

  use Sentry.PlugCapture

  plug(Sentry.PlugContext)
  plug(:assign_org_id)
  plug(:assign_org_username)
  plug(:match)
  plug(:dispatch)

  #
  # Health checks
  #

  get "/" do
    send_resp(conn, 200, "")
  end

  get "/is_alive" do
    send_resp(conn, 200, "")
  end

  #
  # OpenID JSON Web Key Sets endpoint
  # https://auth0.com/docs/secure/tokens/json-web-tokens/json-web-key-sets
  #

  get "/.well-known/jwks" do
    Watchman.benchmark("ocid_well-known-jwks", fn ->
      serve_jwks(conn)
    end)
  end

  get "/.well-known/jwks.json" do
    Watchman.benchmark("ocid_well-known-jwks", fn ->
      serve_jwks(conn)
    end)
  end

  #
  # OpenID Configuration Endpoint
  #
  @openid_configuration_cache_max_age 15 * 60

  get "/.well-known/openid-configuration" do
    Watchman.benchmark("ocid_well-known-configuration", fn ->
      {issuer, jwks_uri, claims_supported} = openid_endpoints(conn)
      configuration = openid_configuration(issuer, jwks_uri, claims_supported)

      conn
      |> put_well_known_cache_control_header()
      |> json(200, configuration)
    end)
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  #
  # Utilities
  #
  defp openid_configuration(issuer, jwks_uri, claims_supported) do
    %{
      "issuer" => issuer,
      "jwks_uri" => jwks_uri,
      "subject_types_supported" => [
        "public",
        "pairwise"
      ],
      "response_types_supported" => ["id_token"],
      "claims_supported" => claims_supported,
      "id_token_signing_alg_values_supported" => ["RS256"],
      "scopes_supported" => ["openid"]
    }
  end

  # Resolves the issuer/jwks_uri/claims for the request. The global cache issuer
  # (host `cache.<base_domain>`) uses a dedicated keyset and claim set; every
  # other host is treated as a per-organization issuer.
  defp openid_endpoints(conn) do
    if cache_request?(conn) do
      issuer = Secrethub.OpenIDConnect.CacheJWT.issuer()

      {issuer, "#{issuer}/.well-known/jwks.json", Secrethub.OpenIDConnect.CacheJWT.claims()}
    else
      base_domain = Application.fetch_env!(:secrethub, :domain)
      org_username = conn.assigns.org_username
      issuer = "https://#{org_username}.#{base_domain}"

      {issuer, "#{issuer}/.well-known/jwks.json",
       Secrethub.OpenIDConnect.JWT.claims(conn.assigns.org_id)}
    end
  end

  defp serve_jwks(conn) do
    keyset = if cache_request?(conn), do: :cache_openid_keys, else: :openid_keys
    public_keys = Secrethub.OpenIDConnect.KeyManager.public_keys(keyset)
    Secrethub.OpenIDConnect.Utilization.submit_usage(conn.host)

    conn
    |> put_well_known_cache_control_header()
    |> json(200, %{"keys" => public_keys})
  end

  defp cache_request?(conn) do
    conn.assigns.org_username == Secrethub.OpenIDConnect.CacheJWT.cache_subdomain()
  end

  # sobelow_skip ["XSS.SendResp"]
  defp json(conn, code, map) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(code, Poison.encode!(map))
  end

  defp assign_org_id(conn, _) do
    id = conn |> get_req_header("x-semaphore-org-id") |> List.first()

    assign(conn, :org_id, id)
  end

  defp assign_org_username(conn, _) do
    username = conn |> get_req_header("x-semaphore-org-username") |> List.first()

    assign(conn, :org_username, username)
  end

  defp put_well_known_cache_control_header(conn) do
    put_resp_header(conn, "cache-control", well_known_cache_control_header())
  end

  defp well_known_cache_control_header do
    max_age =
      Secrethub.OpenIDConnect.KeyManager.cache_max_age_in_seconds()
      |> max(@openid_configuration_cache_max_age)

    "max-age=#{max_age}, public, must-revalidate"
  end
end
