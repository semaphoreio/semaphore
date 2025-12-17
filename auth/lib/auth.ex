defmodule Auth do
  use Plug.Router

  use Plug.ErrorHandler
  use Sentry.PlugCapture

  plug(Auth.RefuseXSemaphoreHeaders)

  plug(Plug.Logger, log: :debug)
  plug(RemoteIp, proxies: {__MODULE__, :proxies, []})

  def proxies, do: Application.fetch_env!(:auth, :trusted_proxies)

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
  # OAuth 2.1 Protected Resource Metadata (RFC 9728) for MCP
  # This endpoint must be accessible without authentication
  #
  get "/.well-known/oauth-protected-resource", host: "mcp." do
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

  #
  # DCR Proxy for MCP OAuth 2.1 - bypasses Keycloak CORS issues
  # This endpoint must be accessible without authentication
  #
  post "/oauth/register", host: "mcp." do
    log_request(conn, "mcp.#{Application.fetch_env!(:auth, :domain)}/oauth/register")

    {:ok, body, conn} = Plug.Conn.read_body(conn)

    case proxy_dcr_to_keycloak(body) do
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
  end

  # Handle CORS preflight for DCR endpoint
  options "/oauth/register", host: "mcp." do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Content-Type")
    |> send_resp(204, "")
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
          {:ok, user_id, _claims} ->
            conn
            |> put_resp_header("x-semaphore-user-id", user_id)
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
        {:ok, response_body}

      {:ok, status, _headers, response_body} ->
        Logger.warning("[Auth] DCR proxy failed with status #{status}: #{response_body}")
        {:error, status, response_body}

      {:error, reason} ->
        Logger.error("[Auth] DCR proxy request failed: #{inspect(reason)}")
        {:error, 500, Jason.encode!(%{error: "DCR request failed"})}
    end
  end
end
