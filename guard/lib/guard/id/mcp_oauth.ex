defmodule Guard.Id.McpOAuth do
  @moduledoc """
  MCP OAuth grant selection controller.

  Handles the consent flow for MCP OAuth grants during authorization.
  """

  require Logger

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  # GET /mcp/oauth/grant-selection
  #
  # Shows grant selection UI to the user during OAuth flow.
  #
  # Query params:
  # - state: Keycloak auth session tab ID (for correlation)
  # - client_id: OAuth client requesting access
  # - user_id: Keycloak user ID (OIDC user ID)
  # - scopes: Requested OAuth scopes (URL encoded)
  get "/grant-selection" do
    state = conn.params["state"]
    client_id = conn.params["client_id"]
    oidc_user_id = conn.params["user_id"]
    scopes = conn.params["scopes"] || ""

    Logger.info(
      "[McpOAuth] Grant selection requested for client=#{client_id}, user=#{oidc_user_id}, scopes=#{scopes}"
    )

    # For Phase 4, we'll implement a simple HTML response
    # In a future phase, this would be a full UI with organization/project selection

    html_response = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>MCP Grant Selection</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { color: #333; }
        .info { background: #f0f0f0; padding: 15px; margin: 20px 0; }
        .scopes { margin: 20px 0; }
        .scope-item { padding: 5px 0; }
        button { background: #4CAF50; color: white; padding: 10px 20px; border: none; cursor: pointer; }
        button:hover { background: #45a049; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Authorize MCP Access</h1>
        <div class="info">
          <p><strong>Client:</strong> #{client_id}</p>
          <p><strong>Requested Scopes:</strong></p>
          <div class="scopes">
            #{parse_scopes_html(scopes)}
          </div>
        </div>
        <p>Grant selection UI will be implemented in future phase.</p>
        <p>For now, clicking authorize will create a grant with full access.</p>
        <form action="/mcp/oauth/grant-selection" method="post">
          <input type="hidden" name="state" value="#{state}" />
          <input type="hidden" name="client_id" value="#{client_id}" />
          <input type="hidden" name="oidc_user_id" value="#{oidc_user_id}" />
          <input type="hidden" name="user_id" value="to_be_determined" />
          <input type="hidden" name="tool_scopes" value="#{scopes}" />
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

  # POST /mcp/oauth/grant-selection
  #
  # Creates MCP grant and redirects back to Keycloak.
  #
  # Form params:
  # - state: Keycloak auth session tab ID
  # - client_id: OAuth client ID
  # - oidc_user_id: Keycloak user ID
  # - tool_scopes: Requested tool scopes (space-separated)
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

            callback_url =
              "#{keycloak_base_url}/auth/realms/semaphore/login-actions/required-action" <>
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
