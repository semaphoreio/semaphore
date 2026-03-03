defmodule Guard.McpOAuth.Server do
  @moduledoc """
  MCP OAuth 2.0 Authorization Server.

  Implements OAuth 2.0 endpoints for MCP client authentication:
  - /.well-known/oauth-authorization-server (RFC 8414)
  - /.well-known/openid-configuration (OIDC discovery for compatibility)
  - /register (RFC 7591 - Dynamic Client Registration)
  - /authorize (Authorization endpoint)
  - /token (Token endpoint)
  - /grant-selection (legacy fallback; consent UI is served by Front)

  Guard acts as the OAuth Authorization Server, minting JWTs with HS256.
  """

  require Logger

  use Plug.Router

  alias Guard.McpOAuth.{Authorize, Metadata, Register, Token}
  alias Guard.Store.McpOAuthConsentChallenge

  # Note: Plug.Parsers is NOT used here because Guard.Id.Api already parses
  # the body before forwarding to this router. Adding Plug.Parsers here
  # would attempt to re-read an already-consumed body.

  plug(:match)
  plug(:dispatch)

  @consent_ttl_seconds 600

  # ====================
  # Protected Resource Metadata (RFC 9728)
  # ====================

  get "/.well-known/oauth-protected-resource" do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(200, Metadata.get_resource_metadata_json())
  end

  options "/.well-known/oauth-protected-resource" do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> send_resp(204, "")
  end

  # ====================
  # Authorization Server Metadata (RFC 8414)
  # ====================

  get "/.well-known/oauth-authorization-server" do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, Metadata.get_metadata_json())
  end

  # CORS preflight for metadata
  options "/.well-known/oauth-authorization-server" do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type, mcp-protocol-version")
    |> send_resp(204, "")
  end

  # ====================
  # OpenID Connect Discovery (for OIDC-compliant clients)
  # Some MCP clients use OIDC discovery instead of RFC 8414
  # Path insertion: /mcp/oauth/.well-known/openid-configuration
  # ====================

  get "/.well-known/openid-configuration" do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, Metadata.get_metadata_json())
  end

  # CORS preflight for OIDC metadata
  options "/.well-known/openid-configuration" do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type, mcp-protocol-version")
    |> send_resp(204, "")
  end

  # ====================
  # JWKS Endpoint (for OIDC compatibility)
  # Note: We use HS256 (symmetric HMAC) for token signing.
  # HS256 keys cannot be exposed via JWKS (would leak the secret).
  # Token validation is done server-side by the resource server.
  # ====================

  get "/jwks" do
    # Return empty key set - tokens are validated server-side
    jwks = %{
      "keys" => []
    }

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, Jason.encode!(jwks))
  end

  # CORS preflight for JWKS
  options "/jwks" do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type")
    |> send_resp(204, "")
  end

  # ====================
  # Dynamic Client Registration (RFC 7591)
  # ====================

  post "/register" do
    body = conn.body_params

    Logger.debug("[McpOAuth.Server] DCR request received")

    case Register.register(body) do
      {:ok, response} ->
        Logger.debug("[McpOAuth.Server] DCR successful: client_id=#{response["client_id"]}")

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_resp(201, Jason.encode!(response))

      {:error, error_response} ->
        Logger.warning("[McpOAuth.Server] DCR failed: #{inspect(error_response)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_resp(400, Jason.encode!(error_response))
    end
  end

  # CORS preflight for register
  options "/register" do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type")
    |> send_resp(204, "")
  end

  # ====================
  # Authorization Endpoint
  # ====================

  get "/authorize" do
    Logger.debug("[McpOAuth.Server] Authorization request: client_id=#{conn.params["client_id"]}")

    case Authorize.validate_request(conn.params) do
      {:ok, validated_params} ->
        # Check if user is authenticated (has session)
        case get_authenticated_user(conn) do
          {:ok, user} ->
            # User is authenticated, create one-time consent challenge and
            # redirect browser flow to Front consent UI.
            redirect_to_grant_selection(conn, validated_params, user.id)

          {:error, :not_authenticated} ->
            # User not authenticated, redirect to login
            redirect_to_login(conn, validated_params)
        end

      {:error, %{type: :direct} = error} ->
        # Cannot redirect, show error directly
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          400,
          Jason.encode!(%{
            error: error.error,
            error_description: error.error_description
          })
        )

      {:error, %{type: :redirect} = error} ->
        # Can redirect with error
        redirect_url =
          Authorize.build_error_redirect(
            error.redirect_uri,
            error.error,
            error.error_description,
            error.state
          )

        conn
        |> put_resp_header("location", redirect_url)
        |> send_resp(302, "")
    end
  end

  # ====================
  # Grant Selection UI (Consent)
  # ====================

  get "/grant-selection" do
    # Guard no longer renders or processes browser consent forms.
    # Front owns the consent page and submission handling.
    render_grant_selection_form(conn)
  end

  post "/grant-selection" do
    # Guard no longer renders or processes browser consent forms.
    # Front owns the consent page and submission handling.
    render_grant_selection_form(conn)
  end

  # ====================
  # Token Endpoint
  # ====================

  post "/token" do
    body = conn.body_params

    Logger.debug("[McpOAuth.Server] Token request: grant_type=#{body["grant_type"]}")

    case Token.exchange(body) do
      {:ok, response} ->
        Logger.debug("[McpOAuth.Server] Token issued successfully")

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> put_resp_header("cache-control", "no-store")
        |> put_resp_header("pragma", "no-cache")
        |> send_resp(200, Jason.encode!(response))

      {:error, error_response} ->
        Logger.warning("[McpOAuth.Server] Token request failed: #{inspect(error_response)}")

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_resp(400, Jason.encode!(error_response))
    end
  end

  # CORS preflight for token
  options "/token" do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type")
    |> send_resp(204, "")
  end

  # Catch-all
  match _ do
    send_resp(conn, 404, "Not Found")
  end

  # ====================
  # Private Functions
  # ====================

  defp get_authenticated_user(conn) do
    # User ID is set by auth service after validating browser session cookie
    # Auth service handles login redirect if user is not authenticated
    case get_req_header(conn, "x-semaphore-user-id") do
      [user_id] when is_binary(user_id) and user_id != "" ->
        case Guard.Store.RbacUser.fetch(user_id) do
          user when not is_nil(user) -> {:ok, user}
          nil -> {:error, :not_authenticated}
        end

      _ ->
        # No auth header means user not authenticated
        # Auth service would have redirected to login if no session
        {:error, :not_authenticated}
    end
  end

  defp render_grant_selection_form(conn) do
    # Safe fallback: consent UI moved to Front and must start from /authorize.
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(410, "Consent UI moved to Front. Restart OAuth flow at /mcp/oauth/authorize.")
  end

  defp redirect_to_grant_selection(conn, validated_params, user_id) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@consent_ttl_seconds, :second)
      |> DateTime.truncate(:second)

    challenge_attrs = %{
      user_id: user_id,
      client_id: validated_params.client_id,
      client_name: validated_params.client_name,
      redirect_uri: validated_params.redirect_uri,
      code_challenge: validated_params.code_challenge,
      code_challenge_method: "S256",
      state: validated_params.state,
      requested_scope: validated_params.scope,
      expires_at: expires_at
    }

    case McpOAuthConsentChallenge.create(challenge_attrs) do
      {:ok, challenge} ->
        grant_selection_url = build_front_grant_selection_url(challenge.id)

        conn
        |> put_resp_header("location", grant_selection_url)
        |> send_resp(302, "")

      {:error, reason} ->
        Logger.error("[McpOAuth.Server] Failed to create consent challenge: #{inspect(reason)}")

        error_url =
          Authorize.build_error_redirect(
            validated_params.redirect_uri,
            "server_error",
            "Failed to initialize consent challenge",
            validated_params.state
          )

        conn
        |> put_resp_header("location", error_url)
        |> send_resp(302, "")
    end
  end

  defp build_front_grant_selection_url(challenge_id) do
    base_domain = Application.fetch_env!(:guard, :base_domain)

    "https://mcp.#{base_domain}/mcp/oauth/grant-selection?" <>
      URI.encode_query(%{"consent_challenge" => challenge_id})
  end

  defp redirect_to_login(conn, validated_params) do
    # Build the return URL with all OAuth params so user comes back after login
    return_params =
      URI.encode_query(%{
        "client_id" => validated_params.client_id,
        "redirect_uri" => validated_params.redirect_uri,
        "code_challenge" => validated_params.code_challenge,
        "code_challenge_method" => "S256",
        "response_type" => "code",
        "scope" => validated_params.scope,
        "state" => validated_params.state || ""
      })

    return_url = "/mcp/oauth/authorize?#{return_params}"
    login_url = "/login?return_to=#{URI.encode_www_form(return_url)}"

    conn
    |> put_resp_header("location", login_url)
    |> send_resp(302, "")
  end
end
