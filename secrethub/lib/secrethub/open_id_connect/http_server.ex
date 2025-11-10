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
      base_domain = Application.fetch_env!(:secrethub, :domain)
      org_username = conn.assigns.org_username
      org_id = conn.assigns.org_id

      issuer = "https://#{org_username}.#{base_domain}"
      jwks_uri = "https://#{org_username}.#{base_domain}/.well-known/jwks.json"
      configuration = openid_configuration(issuer, jwks_uri, org_id)

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
  defp openid_configuration(issuer, jwks_uri, org_id) do
    %{
      "issuer" => issuer,
      "jwks_uri" => jwks_uri,
      "subject_types_supported" => [
        "public",
        "pairwise"
      ],
      "response_types_supported" => ["id_token"],
      "claims_supported" => Secrethub.OpenIDConnect.JWT.claims(org_id),
      "id_token_signing_alg_values_supported" => ["RS256"],
      "scopes_supported" => ["openid"]
    }
  end

  defp serve_jwks(conn) do
    public_keys = Secrethub.OpenIDConnect.KeyManager.public_keys(:openid_keys)
    Secrethub.OpenIDConnect.Utilization.submit_usage(conn.host)

    conn
    |> put_well_known_cache_control_header()
    |> json(200, %{"keys" => public_keys})
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
