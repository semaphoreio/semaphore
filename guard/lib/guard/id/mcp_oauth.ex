defmodule Guard.Id.McpOAuth do
  @moduledoc """
  MCP OAuth grant selection controller.

  Handles the consent flow for MCP OAuth grants during authorization.
  Uses Keycloak's state parameter to carry OAuth flow data (redirect_uri, client_state, grant_id).
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

  # Grant cache TTL in milliseconds (60 seconds - token exchange happens immediately)
  @grant_cache_ttl :timer.seconds(60)

  @doc """
  GET /oauth/authorize (forwarded as GET /)

  Main OAuth authorization endpoint for MCP flows.
  User is already authenticated via ExtAuth (cookie validation).
  User ID is available in x-semaphore-user-id header.

  Query params:
  - client_id: OAuth client requesting access
  - redirect_uri: Client's callback URL
  - scope: Requested OAuth scopes
  - state: Client's state parameter (passed through)
  - response_type: Must be "code"
  - code_challenge: PKCE code challenge
  - code_challenge_method: PKCE method (S256)
  """
  get "/" do
    # Read user from headers (set by Auth ExtAuth)
    user_id = get_user_from_headers(conn)

    # Extract OAuth parameters
    client_id = conn.params["client_id"]
    redirect_uri = conn.params["redirect_uri"]
    scope = conn.params["scope"] || "mcp"
    client_state = conn.params["state"]
    code_challenge = conn.params["code_challenge"]
    code_challenge_method = conn.params["code_challenge_method"]

    Logger.info(
      "[McpOAuth] Authorization request for client=#{client_id}, user_id=#{user_id}"
    )

    if user_id == nil do
      # Should not happen - ExtAuth redirects to login if not authenticated
      Logger.error("[McpOAuth] No user ID in headers - ExtAuth should have redirected")
      send_resp(conn, 401, "Not authenticated")
    else
      # Lookup user by ID - fetch/1 returns user struct or nil
      case Guard.Store.RbacUser.fetch(user_id) do
        nil ->
          Logger.error("[McpOAuth] User #{user_id} not found in rbac_users")
          send_resp(conn, 401, "User not found")

        rbac_user ->
          # Build OAuth params to pass through the flow
          oauth_params = %{
            client_id: client_id,
            redirect_uri: redirect_uri,
            client_state: client_state,
            scope: scope,
            code_challenge: code_challenge,
            code_challenge_method: code_challenge_method
          }

          # Check for existing grant or show UI
          handle_grant_selection(conn, oauth_params, rbac_user)
      end
    end
  end

  @doc """
  POST /oauth/authorize (forwarded as POST /)

  Creates MCP grant and forwards to Keycloak for token issuance.

  Form params:
  - client_id: OAuth client ID
  - redirect_uri: Client's callback URL
  - client_state: Client's original state parameter
  - tool_scopes: Requested tool scopes (space-separated)
  - code_challenge: PKCE code challenge (optional)
  - code_challenge_method: PKCE method (optional)
  """
  post "/" do
    user_id = get_user_from_headers(conn)
    client_id = conn.params["client_id"]
    redirect_uri = conn.params["redirect_uri"]
    client_state = conn.params["client_state"]
    tool_scopes_param = conn.params["tool_scopes"] || ""
    code_challenge = conn.params["code_challenge"]
    code_challenge_method = conn.params["code_challenge_method"]

    Logger.info("[McpOAuth] Processing authorization grant for client=#{client_id}, user=#{user_id}")

    if user_id == nil do
      send_resp(conn, 401, "Not authenticated")
    else
      # fetch/1 returns user struct or nil
      case Guard.Store.RbacUser.fetch(user_id) do
        nil ->
          Logger.error("[McpOAuth] User #{user_id} not found")
          send_resp(conn, 401, "User not found")

        rbac_user ->
          tool_scopes = parse_tool_scopes(tool_scopes_param)

          # Build PKCE params map
          pkce_params = build_pkce_params(code_challenge, code_challenge_method)

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

              # Forward to Keycloak with all params encoded in state
              forward_to_keycloak(
                conn,
                redirect_uri,
                client_state,
                grant.id,
                grant.tool_scopes,
                client_id,
                pkce_params
              )

            {:error, reason} ->
              Logger.error("[McpOAuth] Failed to create grant: #{inspect(reason)}")
              send_resp(conn, 500, "Failed to create grant. Please try again.")
          end
      end
    end
  end

  @doc """
  GET /mcp/oauth/callback

  Handles OAuth callback from Keycloak.
  Decodes state parameter to get client redirect info and grant_id.
  Caches grant for token exchange, then redirects to client.

  Query params:
  - code: Authorization code from Keycloak
  - state: Encoded OAuth state (redirect_uri, client_state, grant_id, tool_scopes)
  """
  get "/callback" do
    code = conn.params["code"]
    encoded_state = conn.params["state"]

    Logger.info("[McpOAuth] Received Keycloak callback")

    if code && encoded_state do
      case decode_oauth_state(encoded_state) do
        {:ok, %{"r" => redirect_uri, "s" => client_state, "g" => grant_id, "t" => tool_scopes}} ->
          # Cache grant info for token exchange (brief TTL)
          cache_grant_for_code(code, grant_id, tool_scopes)

          # Build client callback URL
          client_callback =
            redirect_uri <>
              "?code=#{URI.encode(code)}" <>
              if(client_state && client_state != "", do: "&state=#{URI.encode(client_state)}", else: "")

          Logger.info("[McpOAuth] Redirecting to client callback: #{redirect_uri}")

          conn
          |> put_resp_header("location", client_callback)
          |> send_resp(302, "")

        {:error, reason} ->
          Logger.error("[McpOAuth] Failed to decode state: #{inspect(reason)}")
          send_resp(conn, 400, "Invalid state parameter")
      end
    else
      Logger.error("[McpOAuth] Missing code or state in Keycloak callback")
      send_resp(conn, 400, "Invalid callback parameters")
    end
  end

  @doc """
  GET /mcp/oauth/pre-authorize

  Legacy pre-authorization endpoint for MCP OAuth flows.
  Shows grant selection UI after user authenticates with Guard.

  Query params:
  - correlation_id: OAuth session correlation ID from Auth service (legacy)
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
        show_legacy_grant_selection_ui(conn, correlation_id, client_id, scope, rbac_user)

      {:error, :not_authenticated} ->
        # Redirect to Keycloak login, then return here
        return_url = conn.request_path <> "?" <> conn.query_string
        redirect_to_keycloak_login(conn, return_url)
    end
  end

  @doc """
  POST /mcp/oauth/pre-authorize

  Legacy: Creates MCP grant and forwards to Keycloak.
  """
  post "/pre-authorize" do
    correlation_id = conn.params["correlation_id"]
    client_id = conn.params["client_id"]
    tool_scopes_param = conn.params["tool_scopes"] || ""

    Logger.info("[McpOAuth] Processing legacy grant creation for client=#{client_id}")

    # Get current user
    case get_current_guard_user(conn) do
      {:ok, rbac_user} ->
        tool_scopes = parse_tool_scopes(tool_scopes_param)

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

            # Legacy: Forward to Keycloak with correlation_id in state
            # This path is for backward compatibility with existing Auth sessions
            forward_to_keycloak_legacy(conn, correlation_id, grant.id, grant.tool_scopes, client_id)

          {:error, reason} ->
            Logger.error("[McpOAuth] Failed to create grant: #{inspect(reason)}")
            send_resp(conn, 500, "Failed to create grant. Please try again.")
        end

      {:error, :not_authenticated} ->
        Logger.error("[McpOAuth] User not authenticated during POST")
        send_resp(conn, 401, "Not authenticated. Please log in again.")
    end
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  # ============================================================================
  # State Encoding/Decoding
  # ============================================================================

  @doc """
  Encode OAuth flow parameters into a state string for Keycloak.
  Uses short keys to minimize URL length.
  """
  defp encode_oauth_state(redirect_uri, client_state, grant_id, tool_scopes) do
    %{
      r: redirect_uri || "",
      s: client_state || "",
      g: grant_id,
      t: tool_scopes || []
    }
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Decode state string back to OAuth parameters.
  Returns {:ok, map} or {:error, reason}.
  """
  defp decode_oauth_state(encoded) do
    with {:ok, json} <- Base.url_decode64(encoded, padding: false),
         {:ok, decoded} <- Jason.decode(json) do
      {:ok, decoded}
    else
      :error -> {:error, :invalid_base64}
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # Grant Cache for Token Exchange
  # ============================================================================

  @doc """
  Cache grant info keyed by auth code for token exchange lookup.
  Uses ETS with automatic cleanup.
  """
  defp cache_grant_for_code(auth_code, grant_id, tool_scopes) do
    # Ensure ETS table exists
    ensure_grant_cache_table()

    expiry = System.monotonic_time(:millisecond) + @grant_cache_ttl

    :ets.insert(:mcp_oauth_grant_cache, {auth_code, grant_id, tool_scopes, expiry})

    Logger.debug("[McpOAuth] Cached grant #{grant_id} for code (expires in #{@grant_cache_ttl}ms)")
  end

  @doc """
  Lookup grant by auth code. Called by Auth service during token exchange.
  Returns {:ok, grant_id, tool_scopes} or {:error, :not_found}.
  """
  def lookup_grant_for_code(auth_code) do
    ensure_grant_cache_table()

    case :ets.lookup(:mcp_oauth_grant_cache, auth_code) do
      [{^auth_code, grant_id, tool_scopes, expiry}] ->
        now = System.monotonic_time(:millisecond)

        if now < expiry do
          # Delete after successful lookup (one-time use)
          :ets.delete(:mcp_oauth_grant_cache, auth_code)
          {:ok, grant_id, tool_scopes}
        else
          # Expired
          :ets.delete(:mcp_oauth_grant_cache, auth_code)
          {:error, :not_found}
        end

      [] ->
        {:error, :not_found}
    end
  end

  defp ensure_grant_cache_table do
    case :ets.info(:mcp_oauth_grant_cache) do
      :undefined ->
        :ets.new(:mcp_oauth_grant_cache, [:set, :public, :named_table])

      _ ->
        :ok
    end
  end

  # ============================================================================
  # Grant Selection Flow
  # ============================================================================

  defp handle_grant_selection(conn, oauth_params, rbac_user) do
    %{client_id: client_id, scope: scope} = oauth_params

    # Check for existing grant (reuse)
    case Guard.McpGrant.Actions.find_existing_grant(rbac_user.id, client_id) do
      {:ok, existing_grant} ->
        Logger.info("[McpOAuth] Found existing grant #{existing_grant.id}, reusing")

        pkce_params = build_pkce_params(oauth_params.code_challenge, oauth_params.code_challenge_method)

        # Reuse existing grant, forward to Keycloak
        forward_to_keycloak(
          conn,
          oauth_params.redirect_uri,
          oauth_params.client_state,
          existing_grant.id,
          existing_grant.tool_scopes,
          client_id,
          pkce_params
        )

      {:error, :not_found} ->
        # Show grant selection UI
        tool_scopes = parse_tool_scopes(scope)
        show_authorization_ui(conn, oauth_params, tool_scopes, rbac_user)
    end
  end

  defp show_authorization_ui(conn, oauth_params, tool_scopes, user) do
    %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      client_state: client_state,
      code_challenge: code_challenge,
      code_challenge_method: code_challenge_method
    } = oauth_params

    # Build hidden fields for form submission
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
          <p><strong>Client:</strong> #{html_escape(client_id)}</p>
          <p><strong>User:</strong> #{html_escape(user.email || user.username || user.id)}</p>
          <p><strong>Requested Scopes:</strong></p>
          <div class="scopes">
            #{Enum.map(tool_scopes, fn scope -> "<div class='scope-item'>• #{html_escape(scope)}</div>" end) |> Enum.join("\n")}
          </div>
        </div>
        <p class="note">Grant selection UI will be enhanced in a future phase to allow selecting specific organizations and projects.</p>
        <p class="note">For now, clicking authorize will create a grant with full access to your resources.</p>
        <form action="/oauth/authorize" method="post">
          <input type="hidden" name="client_id" value="#{html_escape(client_id)}" />
          <input type="hidden" name="redirect_uri" value="#{html_escape(redirect_uri)}" />
          <input type="hidden" name="client_state" value="#{html_escape(client_state)}" />
          <input type="hidden" name="tool_scopes" value="#{html_escape(Enum.join(tool_scopes, " "))}" />
          #{if code_challenge, do: "<input type=\"hidden\" name=\"code_challenge\" value=\"#{html_escape(code_challenge)}\" />", else: ""}
          #{if code_challenge_method, do: "<input type=\"hidden\" name=\"code_challenge_method\" value=\"#{html_escape(code_challenge_method)}\" />", else: ""}
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

  # ============================================================================
  # Keycloak Redirect
  # ============================================================================

  defp forward_to_keycloak(conn, redirect_uri, client_state, grant_id, tool_scopes, client_id, pkce_params) do
    base_url = System.get_env("BASE_DOMAIN") || "localhost"

    # Our callback endpoint (Keycloak redirects here)
    our_callback = "https://id.#{base_url}/mcp/oauth/callback"

    # Encode all OAuth flow data into state parameter
    encoded_state = encode_oauth_state(redirect_uri, client_state, grant_id, tool_scopes)

    # Build Keycloak authorization URL
    keycloak_url =
      "https://id.#{base_url}/realms/semaphore/protocol/openid-connect/auth" <>
        "?client_id=#{URI.encode(client_id || "")}" <>
        "&response_type=code" <>
        "&scope=openid" <>
        "&redirect_uri=#{URI.encode(our_callback)}" <>
        "&state=#{URI.encode(encoded_state)}"

    # Add PKCE parameters if present
    keycloak_url = add_pkce_to_url(keycloak_url, pkce_params)

    Logger.info(
      "[McpOAuth] Forwarding to Keycloak with grant_id=#{grant_id}, pkce=#{pkce_params != %{}}"
    )

    conn
    |> put_resp_header("location", keycloak_url)
    |> send_resp(302, "")
  end

  # Legacy: Uses correlation_id (for backward compatibility with Auth sessions)
  defp forward_to_keycloak_legacy(conn, correlation_id, grant_id, tool_scopes, client_id) do
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
        redirect_uri = "https://id.#{base_url}/mcp/oauth/callback"

        keycloak_url =
          "https://id.#{base_url}/realms/semaphore/protocol/openid-connect/auth" <>
            "?client_id=#{URI.encode(client_id || "")}" <>
            "&response_type=code" <>
            "&scope=openid" <>
            "&redirect_uri=#{URI.encode(redirect_uri)}" <>
            "&state=#{URI.encode(correlation_id)}"

        Logger.info(
          "[McpOAuth] Legacy: Forwarding to Keycloak with correlation_id=#{correlation_id}, grant_id=#{grant_id}"
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

  # ============================================================================
  # Legacy Support Functions
  # ============================================================================

  defp get_current_guard_user(conn) do
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
    base_url = System.get_env("BASE_DOMAIN") || "localhost"
    keycloak_login_url = "https://id.#{base_url}/realms/semaphore/protocol/openid-connect/auth"

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

  defp show_legacy_grant_selection_ui(conn, correlation_id, client_id, scope, user) do
    case Guard.McpGrant.Actions.find_existing_grant(user.id, client_id) do
      {:ok, existing_grant} ->
        Logger.info("[McpOAuth] Found existing grant #{existing_grant.id}, reusing")
        forward_to_keycloak_legacy(conn, correlation_id, existing_grant.id, existing_grant.tool_scopes, client_id)

      {:error, :not_found} ->
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
              <p><strong>Client:</strong> #{html_escape(client_id)}</p>
              <p><strong>User:</strong> #{html_escape(user.email || user.username)}</p>
              <p><strong>Requested Scopes:</strong></p>
              <div class="scopes">
                #{Enum.map(tool_scopes, fn scope -> "<div class='scope-item'>• #{html_escape(scope)}</div>" end) |> Enum.join("\n")}
              </div>
            </div>
            <p class="note">Grant selection UI will be enhanced in a future phase to allow selecting specific organizations and projects.</p>
            <p class="note">For now, clicking authorize will create a grant with full access to your resources.</p>
            <form action="/mcp/oauth/pre-authorize" method="post">
              <input type="hidden" name="correlation_id" value="#{html_escape(correlation_id)}" />
              <input type="hidden" name="client_id" value="#{html_escape(client_id)}" />
              <input type="hidden" name="tool_scopes" value="#{html_escape(Enum.join(tool_scopes, " "))}" />
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

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp get_user_from_headers(conn) do
    conn
    |> Plug.Conn.get_req_header("x-semaphore-user-id")
    |> List.first()
  end

  defp build_pkce_params(code_challenge, code_challenge_method) do
    if code_challenge && code_challenge_method do
      %{code_challenge: code_challenge, code_challenge_method: code_challenge_method}
    else
      %{}
    end
  end

  defp add_pkce_to_url(url, pkce_params) do
    case pkce_params do
      %{code_challenge: cc, code_challenge_method: ccm} when is_binary(cc) and is_binary(ccm) ->
        url <>
          "&code_challenge=#{URI.encode(cc)}" <>
          "&code_challenge_method=#{URI.encode(ccm)}"

      _ ->
        url
    end
  end

  defp parse_tool_scopes(scope_string) do
    scope_string
    |> String.split(" ")
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.map(&String.trim/1)
  end

  defp html_escape(nil), do: ""
  defp html_escape(str) when is_binary(str), do: Plug.HTML.html_escape(str)
  defp html_escape(other), do: html_escape(to_string(other))
end
