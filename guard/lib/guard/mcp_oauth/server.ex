defmodule Guard.McpOAuth.Server do
  @moduledoc """
  MCP OAuth 2.0 Authorization Server.

  Implements OAuth 2.0 endpoints for MCP client authentication:
  - /.well-known/oauth-authorization-server (RFC 8414)
  - /register (RFC 7591 - Dynamic Client Registration)
  - /authorize (Authorization endpoint)
  - /token (Token endpoint)
  - /grant-selection (Consent UI)

  Guard acts as the OAuth Authorization Server, minting JWTs with HS256.
  """

  require Logger

  use Plug.Router

  alias Guard.McpOAuth.{Authorize, Metadata, Register, Token}
  alias Guard.Store.{McpOAuthAuthCode, McpOAuthClient}

  # Note: Plug.Parsers is NOT used here because Guard.Id.Api already parses
  # the body before forwarding to this router. Adding Plug.Parsers here
  # would attempt to re-read an already-consumed body.

  plug(:match)
  plug(:dispatch)

  @auth_code_ttl_seconds 600

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
    |> put_resp_header("access-control-allow-headers", "content-type")
    |> send_resp(204, "")
  end

  # ====================
  # Dynamic Client Registration (RFC 7591)
  # ====================

  post "/register" do
    body = conn.body_params

    Logger.info("[McpOAuth.Server] DCR request received")

    case Register.register(body) do
      {:ok, response} ->
        Logger.info("[McpOAuth.Server] DCR successful: client_id=#{response["client_id"]}")

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
    Logger.info("[McpOAuth.Server] Authorization request: client_id=#{conn.params["client_id"]}")

    case Authorize.validate_request(conn.params) do
      {:ok, validated_params} ->
        # Check if user is authenticated (has session)
        case get_authenticated_user(conn) do
          {:ok, user} ->
            # User is authenticated, show consent UI
            render_grant_selection(conn, validated_params, user)

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
    # This is called after login redirect returns to /authorize
    # which then redirects here with OAuth params in session
    render_grant_selection_form(conn)
  end

  post "/grant-selection" do
    # Process consent form submission
    handle_grant_selection(conn)
  end

  # ====================
  # Token Endpoint
  # ====================

  post "/token" do
    body = conn.body_params

    Logger.info("[McpOAuth.Server] Token request: grant_type=#{body["grant_type"]}")

    case Token.exchange(body) do
      {:ok, response} ->
        Logger.info("[McpOAuth.Server] Token issued successfully")

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

  defp render_grant_selection(conn, validated_params, user) do
    # Render consent UI
    html_response = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Authorize MCP Access</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 40px; background: #f5f5f5; }
        .container { max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; margin-top: 0; font-size: 24px; }
        .client-info { background: #f8f9fa; padding: 15px; border-radius: 4px; margin: 20px 0; }
        .client-name { font-weight: bold; color: #333; }
        .scope-info { margin: 20px 0; }
        .scope-item { padding: 8px 0; border-bottom: 1px solid #eee; }
        .scope-item:last-child { border-bottom: none; }
        .user-info { color: #666; font-size: 14px; margin-bottom: 20px; }
        .buttons { display: flex; gap: 10px; margin-top: 20px; }
        button { padding: 12px 24px; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; }
        .authorize-btn { background: #4CAF50; color: white; flex: 1; }
        .authorize-btn:hover { background: #45a049; }
        .cancel-btn { background: #f5f5f5; color: #666; }
        .cancel-btn:hover { background: #e0e0e0; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Authorize MCP Access</h1>
        <p class="user-info">Logged in as: #{user.name || user.id}</p>
        <div class="client-info">
          <span class="client-name">#{html_escape(validated_params.client_name)}</span>
          <p>wants to access your Semaphore account via MCP.</p>
        </div>
        <div class="scope-info">
          <strong>Requested permissions:</strong>
          <div class="scope-item">Access to MCP tools based on your permissions</div>
        </div>
        <form action="/mcp/oauth/grant-selection" method="post">
          <input type="hidden" name="client_id" value="#{html_escape(validated_params.client_id)}" />
          <input type="hidden" name="redirect_uri" value="#{html_escape(validated_params.redirect_uri)}" />
          <input type="hidden" name="code_challenge" value="#{html_escape(validated_params.code_challenge)}" />
          <input type="hidden" name="state" value="#{html_escape(validated_params.state || "")}" />
          <input type="hidden" name="scope" value="#{html_escape(validated_params.scope)}" />
          <input type="hidden" name="user_id" value="#{user.id}" />
          <input type="hidden" name="_csrf_token" value="#{Plug.CSRFProtection.get_csrf_token()}" />
          <div class="buttons">
            <button type="button" class="cancel-btn" onclick="window.location.href='#{html_escape(Authorize.build_error_redirect(validated_params.redirect_uri, "access_denied", "User denied access", validated_params.state))}'">Cancel</button>
            <button type="submit" class="authorize-btn">Authorize</button>
          </div>
        </form>
      </div>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html_response)
  end

  defp render_grant_selection_form(conn) do
    # Fallback for direct access to grant-selection
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(400, "Please start OAuth flow from /authorize endpoint")
  end

  defp handle_grant_selection(conn) do
    params = conn.body_params

    client_id = params["client_id"]
    redirect_uri = params["redirect_uri"]
    code_challenge = params["code_challenge"]
    state = params["state"]
    user_id = params["user_id"]

    Logger.info("[McpOAuth.Server] Grant selection: client=#{client_id}, user=#{user_id}")

    # Validate the client and redirect_uri again
    case McpOAuthClient.find_by_client_id(client_id) do
      {:ok, client} ->
        if McpOAuthClient.valid_redirect_uri?(client, redirect_uri) do
          # Generate authorization code
          code = McpOAuthAuthCode.generate_code()
          expires_at =
            DateTime.utc_now()
            |> DateTime.add(@auth_code_ttl_seconds, :second)
            |> DateTime.truncate(:second)

          auth_code_params = %{
            code: code,
            client_id: client_id,
            user_id: user_id,
            redirect_uri: redirect_uri,
            code_challenge: code_challenge,
            expires_at: expires_at
          }

          case McpOAuthAuthCode.create(auth_code_params) do
            {:ok, _auth_code} ->
              # Redirect back to client with authorization code
              success_url = Authorize.build_success_redirect(redirect_uri, code, state)

              conn
              |> put_resp_header("location", success_url)
              |> send_resp(302, "")

            {:error, reason} ->
              Logger.error("[McpOAuth.Server] Failed to create auth code: #{inspect(reason)}")

              error_url =
                Authorize.build_error_redirect(
                  redirect_uri,
                  "server_error",
                  "Failed to create authorization code",
                  state
                )

              conn
              |> put_resp_header("location", error_url)
              |> send_resp(302, "")
          end
        else
          error_url =
            Authorize.build_error_redirect(
              redirect_uri,
              "invalid_request",
              "Invalid redirect_uri",
              state
            )

          conn
          |> put_resp_header("location", error_url)
          |> send_resp(302, "")
        end

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(400, "Invalid client_id")
    end
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

  defp html_escape(nil), do: ""

  defp html_escape(string) when is_binary(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
