defmodule Guard.Id.McpOAuth do
  @moduledoc """
  MCP OAuth grant selection controller.

  Handles the consent flow for MCP OAuth grants during authorization.
  """

  require Logger

  use Plug.Router

  # Parse query parameters and request body
  # CRITICAL: This must come BEFORE :match to populate conn.params
  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  @doc """
  GET /mcp/oauth/pre-authorize

  Pre-authorization endpoint for MCP OAuth flows.
  Shows grant selection UI after user authenticates with Guard.

  Query params:
  - correlation_id: OAuth session correlation ID from Auth service
  - client_id: OAuth client requesting access
  - scope: Requested OAuth scopes
  """
  get "/pre-authorize" do
    correlation_id = conn.params["correlation_id"]
    client_id = conn.params["client_id"]
    scope = conn.params["scope"] || ""

    Logger.info(
      "[McpOAuth] Pre-authorization requested for client=#{client_id}, correlation=#{correlation_id}"
    )

    # Check if user is logged in with Guard (Keycloak session)
    case get_current_guard_user(conn) do
      {:ok, rbac_user} ->
        # User is authenticated, show grant selection UI
        show_grant_selection_ui(conn, correlation_id, client_id, scope, rbac_user)

      {:error, :not_authenticated} ->
        # Redirect to Keycloak login, then return here
        return_url = conn.request_path <> "?" <> conn.query_string
        redirect_to_keycloak_login(conn, return_url)
    end
  end

  defp get_current_guard_user(conn) do
    # Check for existing Keycloak session cookie
    # This is a simplified check - in production, you'd validate the session
    case Plug.Conn.get_session(conn, "oidc_user_id") do
      nil ->
        {:error, :not_authenticated}

      oidc_user_id ->
        case Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id) do
          {:ok, rbac_user} -> {:ok, rbac_user}
          {:error, _} -> {:error, :not_authenticated}
        end
    end
  end

  defp redirect_to_keycloak_login(conn, return_url) do
    # Store return URL in session and redirect to Keycloak
    base_url = System.get_env("BASE_DOMAIN") || "localhost"

    # Keycloak 17+ uses path without /auth prefix
    keycloak_login_url =
      "https://id.#{base_url}/realms/semaphore/protocol/openid-connect/auth"

    # Build Keycloak login URL with return to this page
    # CRITICAL: Use URI.encode_query to properly encode ALL query parameters
    # This prevents the query string in return_url from being misinterpreted
    callback_params = URI.encode_query(%{"return_to" => return_url})
    redirect_uri = "https://id.#{base_url}/oidc/callback?#{callback_params}"

    keycloak_params =
      URI.encode_query(%{
        "client_id" => "guard",
        "response_type" => "code",
        "redirect_uri" => redirect_uri
      })

    keycloak_url = "#{keycloak_login_url}?#{keycloak_params}"

    Logger.debug("[McpOAuth] Redirecting to Keycloak login: #{keycloak_url}")

    conn
    |> put_resp_header("location", keycloak_url)
    |> send_resp(302, "")
  end

  defp show_grant_selection_ui(conn, correlation_id, client_id, scope, user) do
    # Check for existing grant (reuse)
    case Guard.McpGrant.Actions.find_existing_grant(user.id, client_id) do
      {:ok, existing_grant} ->
        Logger.info("[McpOAuth] Found existing grant #{existing_grant.id}, reusing")
        # Reuse existing grant, skip UI and go straight to Keycloak
        forward_to_keycloak(
          conn,
          correlation_id,
          existing_grant.id,
          existing_grant.tool_scopes,
          client_id
        )

      {:error, :not_found} ->
        # Show grant selection UI
        tool_scopes = parse_tool_scopes(scope)

        html_response = """
        <!DOCTYPE html>
        <html>
        <head>
          <title>Authorize MCP Access</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            h1 { color: #333; margin-top: 0; }
            .info { background: #f0f0f0; padding: 15px; margin: 20px 0; border-radius: 4px; }
            .scopes { margin: 15px 0; }
            .scope-item { padding: 5px 0; color: #555; }
            button { background: #4CAF50; color: white; padding: 12px 24px; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
            button:hover { background: #45a049; }
            .note { color: #666; font-size: 14px; margin-top: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Authorize MCP Access</h1>
            <div class="info">
              <p><strong>Client:</strong> #{client_id}</p>
              <p><strong>User:</strong> #{user.email || user.username}</p>
              <p><strong>Requested Scopes:</strong></p>
              <div class="scopes">
                #{Enum.map(tool_scopes, fn scope -> "<div class='scope-item'>• #{scope}</div>" end) |> Enum.join("\n")}
              </div>
            </div>
            <p class="note">Grant selection UI will be enhanced in a future phase to allow selecting specific organizations and projects.</p>
            <p class="note">For now, clicking authorize will create a grant with full access to your resources.</p>
            <form action="/mcp/oauth/pre-authorize" method="post">
              <input type="hidden" name="correlation_id" value="#{correlation_id}" />
              <input type="hidden" name="client_id" value="#{client_id}" />
              <input type="hidden" name="tool_scopes" value="#{Enum.join(tool_scopes, " ")}" />
              <button type="submit">Authorize Access</button>
            </form>
          </div>
        </body>
        </html>
        """

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html_response)
    end
  end

  defp parse_tool_scopes(scope_string) do
    scope_string
    |> String.split(" ")
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.map(&String.trim/1)
  end

  defp forward_to_keycloak(conn, correlation_id, grant_id, tool_scopes, client_id) do
    # Update Auth service's OAuth session with grant info
    base_url = System.get_env("BASE_DOMAIN") || "localhost"
    auth_url = "https://mcp.#{base_url}/exauth/internal/oauth-session/#{correlation_id}/grant"

    body =
      Jason.encode!(%{
        grant_id: grant_id,
        tool_scopes: tool_scopes
      })

    headers = [{"Content-Type", "application/json"}]

    case :hackney.request(:post, auth_url, headers, body, [:with_body, recv_timeout: 10_000]) do
      {:ok, 200, _headers, _response} ->
        # Successfully stored grant, continue to Keycloak
        redirect_uri = "https://id.#{base_url}/mcp/oauth/callback"

        keycloak_url =
          "https://id.#{base_url}/realms/semaphore/protocol/openid-connect/auth" <>
            "?client_id=#{URI.encode(client_id || "")}" <>
            "&response_type=code" <>
            "&scope=openid" <>
            "&redirect_uri=#{URI.encode(redirect_uri)}" <>
            "&state=#{URI.encode(correlation_id)}"

        Logger.info(
          "[McpOAuth] Forwarding to Keycloak with correlation_id=#{correlation_id}, grant_id=#{grant_id}"
        )

        conn
        |> put_resp_header("location", keycloak_url)
        |> send_resp(302, "")

      {:ok, status, _headers, error_body} ->
        Logger.error(
          "[McpOAuth] Failed to store grant in Auth service: #{status} - #{error_body}"
        )

        send_resp(conn, 500, "Failed to complete authorization. Please try again.")

      {:error, reason} ->
        Logger.error("[McpOAuth] Failed to call Auth service: #{inspect(reason)}")
        send_resp(conn, 500, "Failed to complete authorization. Please try again.")
    end
  end

  @doc """
  POST /mcp/oauth/pre-authorize

  Creates MCP grant and forwards to Keycloak.

  Form params:
  - correlation_id: OAuth session correlation ID
  - client_id: OAuth client ID
  - tool_scopes: Requested tool scopes (space-separated)
  """
  post "/pre-authorize" do
    correlation_id = conn.params["correlation_id"]
    client_id = conn.params["client_id"]
    tool_scopes_param = conn.params["tool_scopes"] || ""

    Logger.info("[McpOAuth] Processing grant creation for client=#{client_id}")

    # Get current user
    case get_current_guard_user(conn) do
      {:ok, rbac_user} ->
        # Parse tool scopes
        tool_scopes = parse_tool_scopes(tool_scopes_param)

        # Create MCP grant
        grant_params = %{
          user_id: rbac_user.id,
          client_id: client_id,
          client_name: client_id,
          tool_scopes: tool_scopes,
          org_grants: [],
          project_grants: [],
          expires_at: nil
        }

        case Guard.McpGrant.Actions.create(grant_params) do
          {:ok, grant} ->
            Logger.info(
              "[McpOAuth] Created grant #{grant.id} for user=#{rbac_user.id}, client=#{client_id}"
            )

            # Forward to Keycloak (this will update Auth's OAuth session)
            forward_to_keycloak(conn, correlation_id, grant.id, grant.tool_scopes, client_id)

          {:error, reason} ->
            Logger.error("[McpOAuth] Failed to create grant: #{inspect(reason)}")
            send_resp(conn, 500, "Failed to create grant. Please try again.")
        end

      {:error, :not_authenticated} ->
        Logger.error("[McpOAuth] User not authenticated during POST")
        send_resp(conn, 401, "Not authenticated. Please log in again.")
    end
  end

  @doc """
  POST /mcp/oauth/grant-selection

  DEPRECATED: Old route for Required Action approach.
  Kept for backward compatibility during migration.

  Creates MCP grant and redirects back to Keycloak.

  Form params:
  - state: Keycloak auth session tab ID
  - client_id: OAuth client ID
  - oidc_user_id: Keycloak user ID
  - tool_scopes: Requested tool scopes (space-separated)
  """
  post "/grant-selection" do
    state = conn.params["state"]
    client_id = conn.params["client_id"]
    oidc_user_id = conn.params["oidc_user_id"]
    tool_scopes_param = conn.params["tool_scopes"] || ""

    Logger.info(
      "[McpOAuth] Processing grant creation for client=#{client_id}, user=#{oidc_user_id}"
    )

    # Map OIDC user ID to Semaphore user ID
    case Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id) do
      {:ok, rbac_user} ->
        # Parse tool scopes from space-separated string
        tool_scopes =
          tool_scopes_param
          |> String.split(" ")
          |> Enum.filter(&(String.trim(&1) != ""))
          |> Enum.map(&String.trim/1)

        # Create MCP grant
        # For Phase 4, we create a grant with empty org_grants and project_grants
        # Full org/project selection UI will be added in future phase
        grant_params = %{
          user_id: rbac_user.id,
          client_id: client_id,
          client_name: client_id,
          # Default name, could fetch from Keycloak
          tool_scopes: tool_scopes,
          org_grants: [],
          project_grants: [],
          expires_at: nil
          # No expiration for now
        }

        case Guard.McpGrant.Actions.create(grant_params) do
          {:ok, grant} ->
            Logger.info(
              "[McpOAuth] Created grant #{grant.id} for user=#{rbac_user.id}, client=#{client_id}"
            )

            # Build redirect URL back to Keycloak
            # The Required Action will read grant_id from query param and set session notes
            keycloak_base_url = System.get_env("KEYCLOAK_BASE_URL") || "http://localhost:8080"

            # Keycloak 17+ uses path without /auth prefix
            callback_url =
              "#{keycloak_base_url}/realms/semaphore/login-actions/required-action" <>
                "?session_code=#{URI.encode(state)}" <>
                "&execution=MCP_GRANT_SELECTION" <>
                "&mcp_grant_id=#{grant.id}" <>
                "&mcp_tool_scopes=#{URI.encode(Enum.join(tool_scopes, " "))}"

            Logger.info("[McpOAuth] Redirecting back to Keycloak: #{callback_url}")

            conn
            |> put_resp_header("location", callback_url)
            |> send_resp(302, "")

          {:error, reason} ->
            Logger.error("[McpOAuth] Failed to create grant: #{inspect(reason)}")

            error_html = """
            <!DOCTYPE html>
            <html>
            <head>
              <title>Error</title>
              <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .error { background: #ffebee; color: #c62828; padding: 20px; border-radius: 4px; }
              </style>
            </head>
            <body>
              <h1>Error Creating Grant</h1>
              <div class="error">
                <p>Failed to create MCP grant. Please try again or contact support.</p>
                <p>Error: #{inspect(reason)}</p>
              </div>
            </body>
            </html>
            """

            conn
            |> put_resp_content_type("text/html")
            |> send_resp(500, error_html)
        end

      {:error, :not_found} ->
        Logger.error("[McpOAuth] OIDC user #{oidc_user_id} not found in rbac_users")

        error_html = """
        <!DOCTYPE html>
        <html>
        <head>
          <title>Error</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .error { background: #ffebee; color: #c62828; padding: 20px; border-radius: 4px; }
          </style>
        </head>
        <body>
          <h1>User Not Found</h1>
          <div class="error">
            <p>Could not find user account. Please contact support.</p>
          </div>
        </body>
        </html>
        """

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(404, error_html)
    end
  end

  @doc """
  GET /mcp/oauth/callback

  Handles OAuth callback from Keycloak.
  Stores auth code in OAuth session and redirects to client.

  Query params:
  - code: Authorization code from Keycloak
  - state: correlation_id for OAuth session
  """
  get "/callback" do
    code = conn.params["code"]
    correlation_id = conn.params["state"]

    Logger.info("[McpOAuth] Received Keycloak callback with correlation_id=#{correlation_id}")

    if code && correlation_id do
      # Update Auth's OAuth session with auth code
      base_url = System.get_env("BASE_DOMAIN") || "localhost"

      auth_url =
        "https://mcp.#{base_url}/exauth/internal/oauth-session/#{correlation_id}/auth-code"

      body = Jason.encode!(%{auth_code: code})
      headers = [{"Content-Type", "application/json"}]

      case :hackney.request(:post, auth_url, headers, body, [:with_body, recv_timeout: 10_000]) do
        {:ok, 200, _headers, response_body} ->
          # Successfully stored auth code, get redirect info
          case Jason.decode(response_body) do
            {:ok, %{"redirect_uri" => redirect_uri, "client_state" => client_state}} ->
              # Redirect to client's original callback
              client_callback =
                redirect_uri <>
                  "?code=#{URI.encode(code)}" <>
                  if(client_state, do: "&state=#{URI.encode(client_state)}", else: "")

              Logger.info("[McpOAuth] Redirecting to client callback: #{redirect_uri}")

              conn
              |> put_resp_header("location", client_callback)
              |> send_resp(302, "")

            {:error, _} ->
              Logger.error("[McpOAuth] Failed to parse Auth response")
              send_resp(conn, 500, "Failed to complete authorization")
          end

        {:ok, status, _headers, error_body} ->
          Logger.error("[McpOAuth] Failed to store auth code: #{status} - #{error_body}")
          send_resp(conn, 500, "Failed to complete authorization")

        {:error, reason} ->
          Logger.error("[McpOAuth] Failed to call Auth service: #{inspect(reason)}")
          send_resp(conn, 500, "Failed to complete authorization")
      end
    else
      Logger.error("[McpOAuth] Missing code or state in Keycloak callback")
      send_resp(conn, 400, "Invalid callback parameters")
    end
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp parse_scopes_html(scopes_string) do
    scopes_string
    |> String.split(" ")
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.map(&"<div class='scope-item'>• #{&1}</div>")
    |> Enum.join("\n")
  end
end
