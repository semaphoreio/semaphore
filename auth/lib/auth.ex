defmodule Auth do
  use Plug.Router

  use Plug.ErrorHandler
  use Sentry.PlugCapture

  plug(Auth.RefuseXSemaphoreHeaders)

  plug(Plug.Logger, log: :debug)
  plug(RemoteIp, proxies: {__MODULE__, :proxies, []})

  def proxies, do: Application.fetch_env!(:auth, :trusted_proxies)

  # Parse query parameters and request body
  # CRITICAL: This must come BEFORE :match to populate conn.params
  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  plug(Sentry.PlugContext)
  require Logger

  #
  # Routes for k8s probes
  #
  get "/" do
    send_resp(conn, 200, "yes")
  end

  get "/is_alive" do
    send_resp(conn, 200, "yes")
  end

  get "/exauth/is_alive" do
    send_resp(conn, 200, "yes")
  end

  get "/exauth/ambassador/v0/check_alive" do
    send_resp(conn, 200, "yes")
  end

  get "/exauth/ambassador/v0/check_ready" do
    send_resp(conn, 200, "yes")
  end

  #
  # OAuth 2.0 Authorization Server Metadata (RFC 8414) for Keycloak
  # IMPORTANT: These routes must come BEFORE the catch-all routes for id. host
  # This endpoint proxies to Keycloak's OpenID Connect discovery endpoint
  # OIDC metadata is a superset of OAuth 2.0 AS metadata, so we can forward it directly
  #
  # ROUTE ORDER CRITICAL: Base route (no path) must come BEFORE wildcard route!
  #
  # Base path (no issuer component) - for MCP 2025-03-26 spec and simple clients
  # CRITICAL: Rewrites OAuth endpoint URLs to point to Auth service (OAuth Proxy Pattern)
  get "/exauth/.well-known/oauth-authorization-server", host: "id." do
    log_request(
      conn,
      "id.#{Application.fetch_env!(:auth, :domain)}/.well-known/oauth-authorization-server"
    )

    domain = Application.fetch_env!(:auth, :domain)
    keycloak_oidc_url = "https://id.#{domain}/realms/semaphore/.well-known/openid-configuration"

    case :hackney.request(:get, keycloak_oidc_url, [], "", [:with_body, recv_timeout: 10_000]) do
      {:ok, 200, _headers, body} ->
        # Parse Keycloak's OIDC metadata and rewrite OAuth endpoints
        case Jason.decode(body) do
          {:ok, metadata} ->
            # Rewrite OAuth endpoints to point to Auth service on mcp. subdomain
            # This enables the OAuth Proxy Pattern for MCP grant selection
            rewritten_metadata =
              Map.merge(metadata, %{
                "authorization_endpoint" => "https://mcp.#{domain}/exauth/oauth/authorize",
                "token_endpoint" => "https://mcp.#{domain}/exauth/oauth/token",
                "registration_endpoint" => "https://mcp.#{domain}/oauth/register"
                # Keep issuer unchanged - must match JWT issuer claim from Keycloak
              })

            conn
            |> put_resp_content_type("application/json")
            |> put_resp_header("access-control-allow-origin", "*")
            |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
            |> send_resp(200, Jason.encode!(rewritten_metadata))

          {:error, _reason} ->
            Logger.error("[Auth] Failed to parse Keycloak OIDC metadata")
            send_resp(conn, 500, "Failed to parse authorization server metadata")
        end

      {:ok, status, _headers, error_body} ->
        Logger.error("[Auth] Failed to fetch Keycloak OIDC metadata: #{status} - #{error_body}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")

      {:error, reason} ->
        Logger.error("[Auth] Failed to connect to Keycloak: #{inspect(reason)}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")
    end
  end

  # RFC 8414 path insertion: When issuer has a path component (e.g., /realms/semaphore),
  # the metadata URL is: https://id.{domain}/.well-known/oauth-authorization-server/realms/semaphore
  # We extract the path and proxy to Keycloak's OIDC discovery endpoint
  # This route handles MCP 2024-06-18 spec with issuer path components
  # RFC 8414 path insertion for MCP 2024-06-18 spec compatibility
  # Handles paths like /realms/semaphore when issuer has path component
  get "/exauth/.well-known/oauth-authorization-server/*issuer_path", host: "id." do
    # issuer_path will be ["realms", "semaphore"] for /realms/semaphore
    path = "/" <> Enum.join(issuer_path, "/")

    log_request(
      conn,
      "id.#{Application.fetch_env!(:auth, :domain)}/.well-known/oauth-authorization-server#{path}"
    )

    domain = Application.fetch_env!(:auth, :domain)

    # Only append path if it's a valid issuer path (starts with /realms/)
    # Otherwise ignore the path and return base OIDC configuration
    keycloak_oidc_url =
      if String.starts_with?(path, "/realms/") do
        "https://id.#{domain}#{path}/.well-known/openid-configuration"
      else
        Logger.debug(
          "[Auth] Ignoring invalid issuer path #{path}, returning base OIDC configuration"
        )

        "https://id.#{domain}/realms/semaphore/.well-known/openid-configuration"
      end

    case :hackney.request(:get, keycloak_oidc_url, [], "", [:with_body, recv_timeout: 10_000]) do
      {:ok, 200, _headers, body} ->
        # Parse Keycloak's OIDC metadata and rewrite OAuth endpoints
        case Jason.decode(body) do
          {:ok, metadata} ->
            # Rewrite OAuth endpoints to point to Auth service on mcp. subdomain
            # This enables the OAuth Proxy Pattern for MCP grant selection
            rewritten_metadata =
              Map.merge(metadata, %{
                "authorization_endpoint" => "https://mcp.#{domain}/exauth/oauth/authorize",
                "token_endpoint" => "https://mcp.#{domain}/exauth/oauth/token",
                "registration_endpoint" => "https://mcp.#{domain}/oauth/register"
                # Keep issuer unchanged - must match JWT issuer claim from Keycloak
              })

            conn
            |> put_resp_content_type("application/json")
            |> put_resp_header("access-control-allow-origin", "*")
            |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
            |> send_resp(200, Jason.encode!(rewritten_metadata))

          {:error, _reason} ->
            Logger.error("[Auth] Failed to parse Keycloak OIDC metadata")
            send_resp(conn, 500, "Failed to parse authorization server metadata")
        end

      {:ok, status, _headers, error_body} ->
        Logger.error("[Auth] Failed to fetch Keycloak OIDC metadata: #{status} - #{error_body}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")

      {:error, reason} ->
        Logger.error("[Auth] Failed to connect to Keycloak: #{inspect(reason)}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")
    end
  end

  # CORS preflight for authorization server metadata (base)
  options "/exauth/.well-known/oauth-authorization-server", host: "id." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(204, "")
  end

  # CORS preflight for authorization server metadata (with path)
  options "/exauth/.well-known/oauth-authorization-server/*_issuer_path", host: "id." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(204, "")
  end

  #
  # OAuth 2.0 Authorization Server Metadata for mcp. subdomain
  # MCP clients may query discovery from either id. or mcp. subdomain
  # CRITICAL: Rewrites OAuth endpoint URLs to point to Auth service (OAuth Proxy Pattern)
  #
  get "/exauth/.well-known/oauth-authorization-server", host: "mcp." do
    log_request(
      conn,
      "mcp.#{Application.fetch_env!(:auth, :domain)}/.well-known/oauth-authorization-server"
    )

    domain = Application.fetch_env!(:auth, :domain)
    keycloak_oidc_url = "https://id.#{domain}/realms/semaphore/.well-known/openid-configuration"

    case :hackney.request(:get, keycloak_oidc_url, [], "", [:with_body, recv_timeout: 10_000]) do
      {:ok, 200, _headers, body} ->
        # Parse Keycloak's OIDC metadata and rewrite OAuth endpoints
        case Jason.decode(body) do
          {:ok, metadata} ->
            # Rewrite OAuth endpoints to point to Auth service
            # This enables the OAuth Proxy Pattern for MCP grant selection
            rewritten_metadata =
              Map.merge(metadata, %{
                "authorization_endpoint" => "https://mcp.#{domain}/exauth/oauth/authorize",
                "token_endpoint" => "https://mcp.#{domain}/exauth/oauth/token",
                "registration_endpoint" => "https://mcp.#{domain}/oauth/register"
                # Keep issuer unchanged - must match JWT issuer claim from Keycloak
              })

            conn
            |> put_resp_content_type("application/json")
            |> put_resp_header("access-control-allow-origin", "*")
            |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
            |> send_resp(200, Jason.encode!(rewritten_metadata))

          {:error, _reason} ->
            Logger.error("[Auth] Failed to parse Keycloak OIDC metadata")
            send_resp(conn, 500, "Failed to parse authorization server metadata")
        end

      {:ok, status, _headers, error_body} ->
        Logger.error("[Auth] Failed to fetch Keycloak OIDC metadata: #{status} - #{error_body}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")

      {:error, reason} ->
        Logger.error("[Auth] Failed to connect to Keycloak: #{inspect(reason)}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")
    end
  end

  # CORS preflight for mcp. subdomain authorization server metadata
  options "/exauth/.well-known/oauth-authorization-server", host: "mcp." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(204, "")
  end

  #
  # Keycloak endpoint for the realm
  # Route for id.<domain>/resources
  #
  match "/exauth/resources:path/*rest", host: "id." do
    if String.match?(conn.request_path, ~r/^\/exauth\/resources\/[a-zA-Z0-9]{5}\/(login|common)/) do
      log_request(conn, "id.#{Application.fetch_env!(:auth, :domain)}/resources/*/(login|common)")

      send_resp(conn, 200, "")
    else
      redirect_to_id_page(conn)
    end
  end

  #
  # Routes for id.<domain> hostname
  #
  match "/exauth:path/*rest", host: "id." do
    Logger.debug("hardcoded host: id")

    log_request(conn, "id.#{Application.fetch_env!(:auth, :domain)}")

    case set_user_headers(conn, allow_token: false) do
      {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
      {:error, conn} -> send_resp(conn, 200, "")
    end
  end

  #
  # Routes for me.<domain> hostname
  #
  match "/exauth:path/*rest", host: "me." do
    Logger.debug("hardcoded host: me")

    log_request(conn, "me.#{Application.fetch_env!(:auth, :domain)}")

    case set_user_headers(conn, allow_token: false) do
      {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
      {:error, conn} -> redirect_or_unauthorized(conn, backurl: true)
    end
  end

  #
  # Routes for hooks.<domain>/github hostname
  #
  match "/exauth/github", host: "hooks." do
    send_resp(conn, 200, "")
  end

  #
  # Routes for <org-name>.<domain>/hooks/bitbucket requests.
  #
  post "/exauth/hooks/bitbucket" do
    case conn |> org_from_host() |> find_org() do
      nil ->
        send_resp(conn, 404, "Not Found")

      org ->
        conn
        |> put_resp_header("x-semaphore-org-username", org.username)
        |> put_resp_header("x-semaphore-org-id", org.id)
        |> send_resp(200, "")
    end
  end

  #
  # Routes for artifacts public API
  #
  match "/exauth/api/v1/artifacts:path/*rest" do
    org = conn |> org_from_host() |> find_org()

    cond do
      !org ->
        send_resp(conn, 401, "Unauthorized")

      Auth.IpFilter.block?(conn.remote_ip, org) ->
        send_resp(conn, 404, blocked_ip_response(conn))

      true ->
        conn
        |> put_resp_header("x-semaphore-org-username", org.username)
        |> put_resp_header("x-semaphore-org-id", org.id)
        |> send_resp(200, "")
    end
  end

  #
  # OAuth 2.1 Protected Resource Metadata (RFC 9728) for MCP
  # This endpoint must be accessible without authentication
  # IMPORTANT: Must be before the catch-all .well-known route to match properly
  #
  get "/exauth/.well-known/oauth-protected-resource", host: "mcp." do
    log_request(
      conn,
      "mcp.#{Application.fetch_env!(:auth, :domain)}/.well-known/oauth-protected-resource"
    )

    domain = Application.fetch_env!(:auth, :domain)

    metadata = %{
      resource: "https://mcp.#{domain}",
      authorization_servers: ["https://id.#{domain}/realms/semaphore"],
      scopes_supported: ["mcp"],
      bearer_methods_supported: ["header"],
      resource_documentation: "https://docs.semaphoreci.com/mcp"
    }

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(200, Jason.encode!(metadata))
  end

  # Handle CORS preflight for OAuth protected resource metadata
  options "/exauth/.well-known/oauth-protected-resource", host: "mcp." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(204, "")
  end

  # Handle protected resource metadata with path suffix (e.g., /mcp)
  # Some clients may append the resource path to the metadata URL
  get "/exauth/.well-known/oauth-protected-resource/*resource_path", host: "mcp." do
    log_request(
      conn,
      "mcp.#{Application.fetch_env!(:auth, :domain)}/.well-known/oauth-protected-resource/#{Enum.join(resource_path, "/")}"
    )

    domain = Application.fetch_env!(:auth, :domain)

    metadata = %{
      resource: "https://mcp.#{domain}",
      authorization_servers: ["https://id.#{domain}/realms/semaphore"],
      scopes_supported: ["mcp"],
      bearer_methods_supported: ["header"],
      resource_documentation: "https://docs.semaphoreci.com/mcp"
    }

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(200, Jason.encode!(metadata))
  end

  # Handle CORS preflight for OAuth protected resource metadata with path suffix
  options "/exauth/.well-known/oauth-protected-resource/*resource_path", host: "mcp." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(204, "")
  end

  #
  # OAuth 2.0 Authorization Server Metadata (RFC 8414) for mcp. subdomain
  # Some MCP clients may request AS metadata from MCP server directly
  # instead of following the two-step discovery (protected resource -> AS metadata)
  #
  # ROUTE ORDER CRITICAL: Base route (no path) must come BEFORE wildcard route!
  #
  # Base path for authorization server metadata on mcp. subdomain - for MCP 2025-03-26 spec
  get "/exauth/.well-known/oauth-authorization-server", host: "mcp." do
    log_request(
      conn,
      "mcp.#{Application.fetch_env!(:auth, :domain)}/.well-known/oauth-authorization-server"
    )

    domain = Application.fetch_env!(:auth, :domain)
    keycloak_oidc_url = "https://id.#{domain}/realms/semaphore/.well-known/openid-configuration"

    case :hackney.request(:get, keycloak_oidc_url, [], "", [:with_body, recv_timeout: 10_000]) do
      {:ok, 200, _headers, body} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
        |> send_resp(200, body)

      {:ok, status, _headers, error_body} ->
        Logger.error("[Auth] Failed to fetch Keycloak OIDC metadata: #{status} - #{error_body}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")

      {:error, reason} ->
        Logger.error("[Auth] Failed to connect to Keycloak: #{inspect(reason)}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")
    end
  end

  # RFC 8414 path insertion for MCP 2024-06-18 spec compatibility
  # Handles paths like /realms/semaphore when issuer has path component
  get "/exauth/.well-known/oauth-authorization-server/*issuer_path", host: "mcp." do
    # issuer_path will be ["realms", "semaphore"] for /realms/semaphore
    path = "/" <> Enum.join(issuer_path, "/")

    log_request(
      conn,
      "mcp.#{Application.fetch_env!(:auth, :domain)}/.well-known/oauth-authorization-server#{path}"
    )

    domain = Application.fetch_env!(:auth, :domain)

    # Only append path if it's a valid issuer path (starts with /realms/)
    # Otherwise ignore the path and return base OIDC configuration
    keycloak_oidc_url =
      if String.starts_with?(path, "/realms/") do
        "https://id.#{domain}#{path}/.well-known/openid-configuration"
      else
        Logger.debug(
          "[Auth] Ignoring invalid issuer path #{path}, returning base OIDC configuration"
        )

        "https://id.#{domain}/realms/semaphore/.well-known/openid-configuration"
      end

    case :hackney.request(:get, keycloak_oidc_url, [], "", [:with_body, recv_timeout: 10_000]) do
      {:ok, 200, _headers, body} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
        |> send_resp(200, body)

      {:ok, status, _headers, error_body} ->
        Logger.error("[Auth] Failed to fetch Keycloak OIDC metadata: #{status} - #{error_body}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")

      {:error, reason} ->
        Logger.error("[Auth] Failed to connect to Keycloak: #{inspect(reason)}")
        send_resp(conn, 500, "Failed to fetch authorization server metadata")
    end
  end

  # CORS preflight for authorization server metadata on mcp. subdomain (base)
  options "/exauth/.well-known/oauth-authorization-server", host: "mcp." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(204, "")
  end

  # CORS preflight for authorization server metadata on mcp. subdomain (with path)
  options "/exauth/.well-known/oauth-authorization-server/*_issuer_path", host: "mcp." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(204, "")
  end

  #
  # Routes for <org-name>.<domain>/.well-known requests.
  # The well-known endpoints are a fully public endpoint that advertises our public
  # OpenID Connect keys. Once this request goes throught Auth, it will hit
  # Secrethub.
  #
  # Secrethub needs to know the ID and Username of the organization, but it doesn't
  # need an authenticated user.
  #
  match "/exauth/.well-known/:path" do
    org_name = org_from_host(conn)

    log_request(conn, "#{org_name}.#{Application.fetch_env!(:auth, :domain)}/.well-known")

    case set_org_headers(conn, org_name) do
      {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
      {:error, :missing_organization, conn} -> redirect_or_unauthorized(conn)
      {:error, :unauthorized_ip, conn} -> send_resp(conn, 404, blocked_ip_response(conn))
    end
  end

  #
  # Routes for <org-name>.<domain>/okta/auth request.
  # The POST /okta/auth is a public endpoint which takes auth requests coming from Okta.
  # The Auth procedure is handled by the SAML handler in the Guard service.
  #
  post "/exauth/okta/auth" do
    org_name = org_from_host(conn)

    log_request(conn, "#{org_name}.#{Application.fetch_env!(:auth, :domain)}/okta/auth")

    case set_org_headers(conn, org_name) do
      {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
      {:error, :missing_organization, conn} -> redirect_or_unauthorized(conn)
      {:error, :unauthorized_ip, conn} -> send_resp(conn, 404, blocked_ip_response(conn))
    end
  end

  #
  # Routes for <org-name>.<domain>/okta/scim/* request.
  # The /okta/scim endpoints are verified by Guard based on the Authorization Bearer token
  # that Semaphore creates and pushes down to Okta. There is no need to do any authorization
  # for these requests, because it is handled downstream in the Guard.Okta.Scim API Handler.
  #
  match "/exauth/okta/scim/:path" do
    org_name = org_from_host(conn)

    log_request(conn, "#{org_name}.#{Application.fetch_env!(:auth, :domain)}/okta/scim")

    case set_org_headers(conn, org_name) do
      {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
      {:error, :missing_organization, conn} -> redirect_or_unauthorized(conn)
      {:error, :unauthorized_ip, conn} -> send_resp(conn, 404, blocked_ip_response(conn))
    end
  end

  #
  # Routes for <org-name>.<domain>/api/v1/self_hosted_agents requests.
  #
  match "/exauth/api/v1/self_hosted_agents:path/*rest" do
    org_name = org_from_host(conn)

    case set_org_headers(conn, org_name) do
      {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
      {:error, :missing_organization, conn} -> redirect_or_unauthorized(conn)
      {:error, :unauthorized_ip, conn} -> send_resp(conn, 404, blocked_ip_response(conn))
    end
  end

  #
  # Routes for <org-name>.<domain>/api/v1/logs requests.
  #
  match "/exauth/api/v1/logs:path/*rest" do
    org_name = org_from_host(conn)

    case set_org_headers(conn, org_name) do
      {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
      {:error, :missing_organization, conn} -> redirect_or_unauthorized(conn)
      {:error, :unauthorized_ip, conn} -> send_resp(conn, 404, blocked_ip_response(conn))
    end
  end

  #
  # Routes for <org-name>.<domain>/api/ requests.
  #
  match "/exauth/api:path/*rest" do
    org_name = org_from_host(conn)

    log_request(conn, "#{org_name}.#{Application.fetch_env!(:auth, :domain)}/api")

    if Auth.Cli.call_from_deprecated_cli?(conn) do
      Auth.Cli.reject_cli_client(conn)
    else
      case set_org_and_user_headers(conn, org_name, allow_cookie: false) do
        {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
        {:error, :missing_organization, conn} -> send_resp(conn, 404, "Not Found")
        {:error, :unauthorized_ip, conn} -> send_resp(conn, 404, blocked_ip_response(conn))
        {:error, _, conn} -> send_resp(conn, 401, "Unauthorized")
      end
    end
  end

  #
  # DCR Proxy for MCP OAuth 2.1 - bypasses Keycloak CORS issues
  # This endpoint must be accessible without authentication
  #
  post "/exauth/oauth/register", host: "mcp." do
    log_request(conn, "mcp.#{Application.fetch_env!(:auth, :domain)}/oauth/register")

    # Use conn.body_params populated by Plug.Parsers instead of reading raw body
    # (Plug.Parsers already consumed the body stream)
    case Jason.encode(conn.body_params) do
      {:ok, body_json} ->
        case proxy_dcr_to_keycloak(body_json) do
          {:ok, response} ->
            conn
            |> put_resp_content_type("application/json")
            |> put_resp_header("access-control-allow-origin", "*")
            |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
            |> put_resp_header("access-control-allow-headers", "Content-Type")
            |> send_resp(201, response)

          {:error, status, error_body} ->
            conn
            |> put_resp_content_type("application/json")
            |> put_resp_header("access-control-allow-origin", "*")
            |> send_resp(status, error_body)
        end

      {:error, _} ->
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_resp(400, Jason.encode!(%{error: "invalid_request", error_description: "Invalid JSON body"}))
    end
  end

  # Handle CORS preflight for DCR endpoint
  options "/exauth/oauth/register", host: "mcp." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type")
    |> send_resp(204, "")
  end

  #
  # OAuth Token Endpoint - Proxies to Keycloak and injects MCP grant info
  # Looks up grant_id from OAuth session using auth code
  # Returns enhanced token response with mcp_grant_id and mcp_tool_scopes
  #
  post "/exauth/oauth/token", host: "mcp." do
    log_request(conn, "mcp.#{Application.fetch_env!(:auth, :domain)}/oauth/token")

    # Use conn.body_params populated by Plug.Parsers instead of reading raw body
    # Re-encode as URL-encoded string for Keycloak
    params = conn.body_params
    code = params["code"]
    body = URI.encode_query(params)

    case proxy_token_to_keycloak(body) do
      {:ok, token_response} ->
        # Check if this was an MCP OAuth flow with a grant
        enhanced_response =
          case Auth.OAuthSession.get_by_auth_code(code) do
            {:ok, %{grant_id: grant_id, tool_scopes: tool_scopes}}
            when not is_nil(grant_id) ->
              Logger.info(
                "[Auth.OAuth] Injecting grant info into token response: grant_id=#{grant_id}"
              )

              # Inject MCP grant info into response
              token_response
              |> Map.put("mcp_grant_id", grant_id)
              |> Map.put("mcp_tool_scopes", tool_scopes)

            _ ->
              # Not an MCP flow or grant not found
              token_response
          end

        # Clean up OAuth session
        if code, do: Auth.OAuthSession.delete_by_auth_code(code)

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
        |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization")
        |> put_resp_header("cache-control", "no-store")
        |> put_resp_header("pragma", "no-cache")
        |> send_resp(200, Jason.encode!(enhanced_response))

      {:error, status, error_body} ->
        Logger.error("[Auth.OAuth] Token exchange failed: #{status} - #{error_body}")

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_resp(status, error_body)
    end
  end

  # Handle CORS preflight for token endpoint
  options "/exauth/oauth/token", host: "mcp." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization")
    |> send_resp(204, "")
  end

  #
  # Internal API: Store grant in OAuth Session (called by Guard)
  # Allows Guard to store grant_id in the OAuth session after grant creation
  #
  post "/exauth/internal/oauth-session/:correlation_id/grant", host: "mcp." do
    log_request(conn, "mcp.#{Application.fetch_env!(:auth, :domain)}/internal/oauth-session/#{correlation_id}/grant")

    # Use conn.body_params populated by Plug.Parsers (JSON already parsed)
    params = conn.body_params

    case params do
      %{"grant_id" => grant_id, "tool_scopes" => tool_scopes} ->
        case Auth.OAuthSession.store_grant(correlation_id, grant_id, tool_scopes) do
          {:ok, _session} ->
            Logger.info("[Auth.OAuth] Stored grant #{grant_id} for correlation #{correlation_id}")

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(%{status: "ok"}))

          {:error, :not_found} ->
            Logger.error("[Auth.OAuth] OAuth session not found: #{correlation_id}")

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(404, Jason.encode!(%{error: "Session not found"}))

          {:error, reason} ->
            Logger.error("[Auth.OAuth] Failed to store grant: #{inspect(reason)}")

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(500, Jason.encode!(%{error: "Failed to store grant"}))
        end

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Missing required fields: grant_id, tool_scopes"}))
    end
  end

  #
  # Internal API: Store auth code in OAuth Session (called by Guard)
  # Allows Guard to store the authorization code after Keycloak callback
  # Returns redirect_uri and client_state for final redirect to client
  #
  post "/exauth/internal/oauth-session/:correlation_id/auth-code", host: "mcp." do
    log_request(conn, "mcp.#{Application.fetch_env!(:auth, :domain)}/internal/oauth-session/#{correlation_id}/auth-code")

    # Use conn.body_params populated by Plug.Parsers (JSON already parsed)
    params = conn.body_params

    case params do
      %{"auth_code" => auth_code} ->
        case Auth.OAuthSession.store_auth_code(correlation_id, auth_code) do
          {:ok, session} ->
            Logger.info("[Auth.OAuth] Stored auth code for correlation #{correlation_id}")

            # Return redirect info for Guard to complete the flow
            response = %{
              status: "ok",
              redirect_uri: session.redirect_uri,
              client_state: session.client_state
            }

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(response))

          {:error, :not_found} ->
            Logger.error("[Auth.OAuth] OAuth session not found: #{correlation_id}")

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(404, Jason.encode!(%{error: "Session not found"}))

          {:error, reason} ->
            Logger.error("[Auth.OAuth] Failed to store auth code: #{inspect(reason)}")

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(500, Jason.encode!(%{error: "Failed to store auth code"}))
        end

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Missing required field: auth_code"}))
    end
  end

  #
  # OAuth Authorization Endpoint - Intercepts MCP OAuth flows
  # Detects "mcp" scope and redirects to Guard for grant selection
  # Otherwise forwards to Keycloak for standard OAuth flow
  #
  get "/exauth/oauth/authorize", host: "mcp." do
    log_request(conn, "mcp.#{Application.fetch_env!(:auth, :domain)}/oauth/authorize")

    client_id = conn.params["client_id"]
    scope = conn.params["scope"] || ""
    redirect_uri = conn.params["redirect_uri"]
    state = conn.params["state"]
    response_type = conn.params["response_type"]

    # Only intercept MCP OAuth flows (scope contains "mcp")
    if String.contains?(scope, "mcp") do
      # Create OAuth session for flow correlation
      correlation_id = UUID.uuid4()

      session_data = %{
        client_id: client_id,
        client_state: state,
        redirect_uri: redirect_uri,
        scope: scope,
        response_type: response_type
      }

      case Auth.OAuthSession.create(correlation_id, session_data) do
        {:ok, _} ->
          # Redirect to Guard pre-authorization endpoint
          domain = Application.fetch_env!(:auth, :domain)

          guard_url =
            "https://id.#{domain}/mcp/oauth/pre-authorize" <>
              "?correlation_id=#{URI.encode(correlation_id)}" <>
              "&client_id=#{URI.encode(client_id || "")}" <>
              "&scope=#{URI.encode(scope)}"

          Logger.info(
            "[Auth.OAuth] Intercepting MCP OAuth flow for client=#{client_id}, redirecting to Guard"
          )

          conn
          |> put_resp_header("location", guard_url)
          |> send_resp(302, "")

        {:error, reason} ->
          Logger.error("[Auth.OAuth] Failed to create OAuth session: #{inspect(reason)}")

          send_resp(
            conn,
            500,
            "Failed to initiate OAuth flow. Please try again."
          )
      end
    else
      # Standard OAuth flow (non-MCP) - forward directly to Keycloak
      domain = Application.fetch_env!(:auth, :domain)

      keycloak_url =
        "https://id.#{domain}/realms/semaphore/protocol/openid-connect/auth" <>
          "?client_id=#{URI.encode(client_id || "")}" <>
          "&response_type=#{URI.encode(response_type || "code")}" <>
          "&scope=#{URI.encode(scope)}" <>
          "&redirect_uri=#{URI.encode(redirect_uri || "")}" <>
          if(state, do: "&state=#{URI.encode(state)}", else: "")

      Logger.debug("[Auth.OAuth] Forwarding non-MCP OAuth flow to Keycloak")

      conn
      |> put_resp_header("location", keycloak_url)
      |> send_resp(302, "")
    end
  end

  #
  # Routes for mcp.{domain}/mcp requests - OAuth 2.1 JWT validation
  #
  match "/exauth/mcp:path/*rest", host: "mcp." do
    log_request(conn, "mcp.#{Application.fetch_env!(:auth, :domain)}/mcp")

    case parse_auth_token(conn.req_headers) do
      nil ->
        # No token provided - return 401 with WWW-Authenticate header per MCP spec
        domain = Application.fetch_env!(:auth, :domain)
        resource_metadata = "https://mcp.#{domain}/.well-known/oauth-protected-resource"

        conn
        |> put_resp_header(
          "www-authenticate",
          ~s(Bearer resource_metadata="#{resource_metadata}")
        )
        |> send_resp(401, "Unauthorized")

      token ->
        case Auth.JWT.validate_mcp_token(token) do
          {:ok, user_id, grant_id, tool_scopes, _claims} ->
            # Inject MCP headers for downstream services
            conn
            |> put_resp_header("x-semaphore-user-id", user_id)
            |> put_resp_header("x-mcp-grant-id", grant_id)
            |> put_resp_header("x-mcp-tool-scopes", Enum.join(tool_scopes, ","))
            |> send_resp(200, "")

          {:error, reason} ->
            Logger.warning("[Auth] MCP JWT validation failed: #{inspect(reason)}")
            send_resp(conn, 401, "Unauthorized")
        end
    end
  end

  #
  # Routes for <org-name>.<domain>/badges*
  #
  match "/exauth/badges:path" do
    org_name = org_from_host(conn)

    log_request(conn, "#{org_name}.#{Application.fetch_env!(:auth, :domain)}/badges")

    case set_org_headers(conn, org_name) do
      {:ok, conn_with_headers} -> send_resp(conn_with_headers, 200, "")
      {:error, :missing_organization, conn} -> redirect_or_unauthorized(conn)
      {:error, :unauthorized_ip, conn} -> send_resp(conn, 404, blocked_ip_response(conn))
    end
  end

  #
  # Routes for <org-name>.<domain> hostnames
  #
  match "/exauth:path/*rest" do
    org_name = org_from_host(conn)
    Logger.debug(fn -> "dynamic host: #{org_name}" end)

    log_request(conn, "#{org_name}.#{Application.fetch_env!(:auth, :domain)}")

    case set_public_headers(conn, org_name, allow_token: false) do
      {:ok, conn_with_headers} ->
        send_resp(conn_with_headers, 200, "")

      {:error, :missing_organization, conn} ->
        redirect_or_unauthorized(conn)

      {:error, :missing_user, conn} ->
        redirect_or_unauthorized(conn, backurl: true)

      {:error, :unauthorized_ip, conn} ->
        send_resp(conn, 404, blocked_ip_response(conn))

      {:error, :id_provider_not_allowed, conn} ->
        org = find_org(org_name)
        backurl = current_url(conn) |> URI.encode_www_form()

        # redirect to guard, which will in turn redirect to the organization's SSO aplication
        redirect(
          conn,
          "https://id.#{Application.fetch_env!(:auth, :domain)}/login?org_id=#{org.id}&redirect_to=#{backurl}"
        )
    end
  end

  #
  # Helpers
  #

  def redirect_to_id_page(conn) do
    redirect(conn, "https://id.#{Application.fetch_env!(:auth, :domain)}")
  end

  def redirect_to_id_page(conn, ""), do: redirect_to_id_page(conn)

  def redirect_to_id_page(conn, backurl) do
    redirect(conn, "https://id.#{Application.fetch_env!(:auth, :domain)}?redirect_to=#{backurl}")
  end

  def redirect_or_unauthorized(conn, options \\ []) do
    if String.starts_with?(conn.request_path, "/exauth/api") do
      send_resp(conn, 401, "Unauthorized")
    else
      backurl =
        if Keyword.get(options, :backurl, false) do
          current_url(conn) |> URI.encode_www_form()
        else
          ""
        end

      redirect_to_id_page(conn, backurl)
    end
  end

  # sobelow_skip ["XSS.SendResp"]
  def redirect(conn, location) do
    Logger.debug(fn -> "Redirect to: #{location}" end)

    conn
    |> put_resp_header("location", location)
    |> send_resp(302, "Redirected to #{Plug.HTML.html_escape(location)}")
  end

  def set_public_headers(conn, org_name, params \\ []) do
    fetch_auth = Task.async(fn -> authenticate(conn, params) end)
    fetch_org = Task.async(fn -> find_org(org_name) end)

    org = Task.await(fetch_org)
    auth = Task.await(fetch_auth)
    {_, _, conn} = auth

    cond do
      !org ->
        {:error, :missing_organization, conn}

      Auth.IpFilter.block?(conn.remote_ip, org) ->
        {:error, :unauthorized_ip, conn}

      true ->
        Logger.debug("Set headers")
        Logger.debug(inspect(org))
        Logger.debug(inspect(auth))

        conn = put_resp_header(conn, "x-semaphore-org-username", org.username)
        conn = put_resp_header(conn, "x-semaphore-org-id", org.id)

        case auth do
          {:ok, user, _} ->
            if Auth.IdProvider.id_provider_allowed?(user, org) do
              conn = conn |> put_resp_header("x-semaphore-user-anonymous", "false")
              conn = conn |> put_resp_header("x-semaphore-user-id", user.id)
              {:ok, conn}
            else
              Logger.info(
                "Deleting auth cookie because #{org.username} do not support #{user.id_provider} for user #{user.id}"
              )

              conn = delete_auth_cookie(conn)
              {:error, :id_provider_not_allowed, conn}
            end

          {:error, :anonymous, _} ->
            conn = conn |> put_resp_header("x-semaphore-user-anonymous", "true")
            {:ok, conn}

          {:error, :token_not_allowed, _} ->
            conn = conn |> put_resp_header("x-semaphore-user-anonymous", "true")
            {:ok, conn}

          _ ->
            conn = delete_resp_header(conn, "x-semaphore-org-username")
            conn = delete_resp_header(conn, "x-semaphore-org-id")
            {:error, :missing_user, conn}
        end
    end
  end

  defp delete_auth_cookie(conn) do
    name = Application.fetch_env!(:auth, :cookie_name)
    domain = ".#{Application.fetch_env!(:auth, :domain)}"

    delete_resp_cookie(conn, name, domain: domain)
  end

  def set_org_and_user_headers(conn, org_name, params \\ []) do
    fetch_auth = Task.async(fn -> authenticate(conn, params) end)
    fetch_org = Task.async(fn -> find_org(org_name) end)

    org = Task.await(fetch_org)
    auth = Task.await(fetch_auth)
    {_, _, conn} = auth

    cond do
      !org ->
        {:error, :missing_organization, conn}

      Auth.IpFilter.block?(conn.remote_ip, org) ->
        {:error, :unauthorized_ip, conn}

      true ->
        case auth do
          {:ok, user, _} ->
            if Auth.IdProvider.id_provider_allowed?(user, org) do
              conn = conn |> put_resp_header("x-semaphore-org-username", org.username)
              conn = conn |> put_resp_header("x-semaphore-org-id", org.id)
              conn = conn |> put_resp_header("x-semaphore-user-anonymous", "false")
              conn = conn |> put_resp_header("x-semaphore-user-id", user.id)
              {:ok, conn}
            else
              {:error, :id_provider_not_allowed, conn}
            end

          _ ->
            {:error, :missing_user, conn}
        end
    end
  end

  def set_org_headers(conn, org_name) do
    org = find_org(org_name)

    cond do
      !org ->
        {:error, :missing_organization, conn}

      Auth.IpFilter.block?(conn.remote_ip, org) ->
        {:error, :unauthorized_ip, conn}

      true ->
        Logger.debug("Set headers")
        Logger.debug(inspect(org))

        conn = put_resp_header(conn, "x-semaphore-org-username", org.username)
        conn = put_resp_header(conn, "x-semaphore-org-id", org.id)

        {:ok, conn}
    end
  end

  def set_user_headers(conn, params \\ []) do
    case authenticate(conn, params) do
      {:ok, user, conn} ->
        conn = put_resp_header(conn, "x-semaphore-user-id", user.id)
        {:ok, conn}

      {:error, _, conn} ->
        {:error, conn}
    end
  end

  # By default, this function accepts cookie and API token
  # as the form of authentication for the user.
  # That behavior can be overridden with the
  # `:allow_cookie` and `:allow_token` parameters.
  #
  # NOTE: even if `:allow_token=false`, if an organization has the
  # `:can_use_api_token_in_ui` feature flag enabled, this function allows
  # an API token to be used.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def authenticate(conn, params \\ []) do
    allow_cookie = Keyword.get(params, :allow_cookie, true)
    allow_token = Keyword.get(params, :allow_token, true)

    conn = fetch_cookies(conn)
    token = parse_auth_token(conn.req_headers)

    session_cookie = conn.cookies[Application.fetch_env!(:auth, :cookie_name)]

    cond do
      token != nil && (allow_token || can_use_token?(conn)) ->
        case authenticate_based_on_token(token) do
          {:ok, auth_data} ->
            {:ok, auth_data, conn}

          {:error, error} ->
            {:error, error, conn}
        end

      session_cookie != nil && allow_cookie ->
        case authenticate_based_on_cookie(session_cookie, conn) do
          {:ok, auth_data} ->
            {:ok, auth_data, conn}

          {:error, error} ->
            case conn |> org_from_host() |> find_org() do
              nil ->
                :ok

              org ->
                Logger.info(
                  "Deleting auth cookie because of auth error: #{error} on subdomain: #{org.username}"
                )
            end

            conn = delete_auth_cookie(conn)

            {:error, error, conn}
        end

      session_cookie != nil ->
        {:error, :cookie_not_allowed, conn}

      true ->
        {:error, :anonymous, conn}
    end
  end

  defp can_use_token?(conn) do
    conn
    |> org_from_host()
    |> find_org()
    |> case do
      nil ->
        false

      org ->
        FeatureProvider.feature_enabled?(:can_use_api_token_in_ui, param: org.id)
    end
  end

  def parse_auth_token(headers) do
    # note: Plug downcases all headers

    case List.keyfind(headers, "authorization", 0) do
      {_, auth_header} ->
        case String.split(auth_header, " ", parts: 2) do
          ["Token", token] -> token
          ["Bearer", token] -> token
          _ -> nil
        end

      _ ->
        nil
    end
  end

  def authenticate_based_on_cookie(session_cookie, conn) do
    # cache key needs to be short and simple, constructing one from md5 of the
    # session cookie
    cache_key =
      :crypto.hash(:md5, "#{session_cookie}")
      |> Base.encode16(case: :lower)

    Logger.debug("Authenticating with cookie: #{inspect(session_cookie)}")

    Watchman.benchmark("authenticate_with_cookie.duration", fn ->
      Auth.Cache.fetch!("authentication-based-on-cookie-#{cache_key}", :timer.minutes(5), fn ->
        stub = InternalApi.Auth.Authentication.Stub

        req = %InternalApi.Auth.AuthenticateWithCookieRequest{
          cookie: session_cookie,
          remember_user_token: ""
        }

        endpoint = Application.fetch_env!(:auth, :authentication_grpc_endpoint)
        opts = [timeout: 30_000]

        {:ok, res} = Auth.GrpcClient.call(stub, endpoint, :authenticate_with_cookie, req, opts)

        if res.authenticated do
          {:ok,
           %{
             id: res.user_id,
             id_provider: res.id_provider,
             ip_address: res.ip_address,
             user_agent: res.user_agent
           }}
        else
          {:error, :anonymous}
        end
      end)
    end)
    |> validate_ip_and_user_client(conn)
  end

  defp validate_ip_and_user_client({:ok, user_data} = auth_resp, conn) do
    org = org_from_host(conn) |> find_org()

    if org != nil && FeatureProvider.feature_enabled?(:enforce_cookie_validation, param: org.id) do
      current_request_user_agent = get_req_header(conn, "user-agent") |> List.first()

      case to_charlist(user_data.ip_address) |> :inet.parse_address() do
        {:ok, ip} ->
          if compare_ip_addresses(ip, conn.remote_ip) and
               user_data.user_agent == current_request_user_agent do
            auth_resp
          else
            Logger.error(
              "Cookie not valid. Cookie data: #{inspect(user_data)}. Req ip #{inspect(conn.remote_ip)}"
            )

            {:error, :anonymous}
          end

        e ->
          Watchman.increment("parse_ip_addres_error")
          Logger.error("#{inspect(e)} While parsing ip #{inspect(user_data.ip_address)}")
          {:error, :anonymous}
      end
    else
      auth_resp
    end
  end

  defp validate_ip_and_user_client({:error, _} = auth_resp, _conn), do: auth_resp

  # Does not compare if 2 ip addresses are equal, but rather if they are coming from the same subnet
  #
  # e.g. {145, 202, 101, 23} is considered same as {145, 202, 101, 45}
  defp compare_ip_addresses(ip_1, ip_2) do
    ip_1 |> Tuple.to_list() |> Enum.take(3) == ip_2 |> Tuple.to_list() |> Enum.take(3)
  end

  def authenticate_based_on_token(token) do
    Watchman.benchmark("authenticate_with_token.duration", fn ->
      Auth.Cache.fetch!("authentication-based-on-token-#{token}", :timer.minutes(5), fn ->
        stub = InternalApi.Auth.Authentication.Stub
        req = %InternalApi.Auth.AuthenticateRequest{token: token}
        endpoint = Application.fetch_env!(:auth, :authentication_grpc_endpoint)
        opts = [timeout: 30_000]

        {:ok, res} = Auth.GrpcClient.call(stub, endpoint, :authenticate, req, opts)

        if res.authenticated do
          {:ok, %{id: res.user_id, id_provider: res.id_provider}}
        else
          {:error, :unauthenticated}
        end
      end)
    end)
  end

  def find_org(username) do
    Watchman.benchmark("find_org.duration", fn ->
      Auth.Cache.fetch!("find-org-#{username}", :timer.minutes(5), fn ->
        stub = InternalApi.Organization.OrganizationService.Stub
        req = %InternalApi.Organization.DescribeRequest{org_username: username}
        endpoint = Application.fetch_env!(:auth, :organization_grpc_endpoint)
        opts = [timeout: 30_000]

        case Auth.GrpcClient.call(stub, endpoint, :describe, req, opts) do
          {:ok, %{status: %{code: :OK}} = res} ->
            %{
              id: res.organization.org_id,
              username: username,
              restricted: res.organization.restricted,
              ip_allow_list: res.organization.ip_allow_list,
              allowed_id_providers: res.organization.allowed_id_providers
            }

          {:error, %GRPC.RPCError{message: _, status: 5}} ->
            nil

          _ ->
            nil
        end
      end)
    end)
  end

  def org_from_host(conn) do
    String.replace(conn.host, ".#{Application.fetch_env!(:auth, :domain)}", "")
  end

  defp org_from_params(conn) do
    case Plug.Conn.fetch_query_params(conn).query_params |> Map.fetch("organization") do
      {:ok, organization} -> organization
      :error -> nil
    end
  end

  defp current_url(conn) do
    conn |> request_url |> String.replace("/exauth", "")
  end

  defp log_request(conn, route) do
    Logger.debug(fn -> "Route: #{route}" end)
    Logger.debug(fn -> "Host: #{conn.host}" end)
    Logger.debug(fn -> "Scheme: #{conn.scheme}" end)
    Logger.debug(fn -> "Headers: #{inspect(conn.req_headers)}" end)
    Logger.debug(fn -> "Params: #{inspect(conn.params)}" end)

    org_name = org_from_params(conn) || org_from_host(conn)

    Logger.debug(fn -> "Organization: #{inspect(org_name)}" end)
  end

  defp blocked_ip_response(conn) do
    ip = conn.remote_ip |> :inet.ntoa()

    """
      You cannot access this organization from your current IP address (#{ip}) due to the security settings enabled by the organization administrator.
      Please contact the organization owner/administrator if you think this is a mistake or reach out to our support team.
    """
  end

  @doc """
  Returns true if the application is running on-prem environment.
  """
  def on_prem?, do: System.get_env("ON_PREM") == "true"

  #
  # MCP OAuth 2.1 DCR Proxy
  # Proxies Dynamic Client Registration requests to Keycloak to bypass CORS issues
  #
  defp proxy_dcr_to_keycloak(body) do
    domain = Application.fetch_env!(:auth, :domain)
    dcr_url = "https://id.#{domain}/realms/semaphore/clients-registrations/openid-connect"

    headers = [{"Content-Type", "application/json"}]

    case :hackney.request(:post, dcr_url, headers, body, [:with_body, recv_timeout: 30_000]) do
      {:ok, 201, _headers, response_body} ->
        # NOTE: The PREFERRED solution is to configure Keycloak's "Default Client Scopes" policy
        # (Clients → Client Registration → Anonymous Access → Default Client Scopes)
        # to automatically assign "mcp" scope to all dynamically registered clients.
        #
        # This injection is kept as a fallback for environments where the policy isn't configured,
        # but it's a workaround and not the proper solution.
        case Jason.decode(response_body) do
          {:ok, response_json} ->
            # Add both "scope" (singular, space-separated string per RFC 7591)
            # and "scopes" (plural, array) to handle clients that might expect either format
            modified_response =
              response_json
              |> Map.put("scope", "mcp")
              |> Map.put("scopes", "mcp")

            Logger.info("[Auth.DCR] Injected scopes into DCR response: #{inspect(modified_response)}")
            {:ok, Jason.encode!(modified_response)}

          {:error, decode_error} ->
            Logger.warning(
              "[Auth] Failed to parse DCR response for scope injection: #{inspect(decode_error)}"
            )

            {:ok, response_body}
        end

      {:ok, status, _headers, response_body} ->
        Logger.warning("[Auth] DCR proxy failed with status #{status}: #{response_body}")
        {:error, status, response_body}

      {:error, reason} ->
        Logger.error("[Auth] DCR proxy request failed: #{inspect(reason)}")
        {:error, 500, Jason.encode!(%{error: "DCR request failed"})}
    end
  end

  defp proxy_token_to_keycloak(body) do
    domain = Application.fetch_env!(:auth, :domain)
    token_url = "https://id.#{domain}/realms/semaphore/protocol/openid-connect/token"

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case :hackney.request(:post, token_url, headers, body, [:with_body, recv_timeout: 30_000]) do
      {:ok, 200, _headers, response_body} ->
        case Jason.decode(response_body) do
          {:ok, response_json} ->
            {:ok, response_json}

          {:error, decode_error} ->
            Logger.error(
              "[Auth.OAuth] Failed to parse token response: #{inspect(decode_error)}"
            )

            {:error, 500, Jason.encode!(%{error: "Failed to parse token response"})}
        end

      {:ok, status, _headers, response_body} ->
        Logger.warning("[Auth.OAuth] Token exchange failed with status #{status}: #{response_body}")
        {:error, status, response_body}

      {:error, reason} ->
        Logger.error("[Auth.OAuth] Token exchange request failed: #{inspect(reason)}")
        {:error, 500, Jason.encode!(%{error: "Token exchange request failed"})}
    end
  end
end
