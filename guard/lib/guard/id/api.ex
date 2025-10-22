defmodule Guard.Id.Api do
  @moduledoc """

  """
  require Logger

  use Plug.Router

  plug(RemoteIp, proxies: {__MODULE__, :proxies, []})

  def proxies, do: Application.fetch_env!(:guard, :trusted_proxies)

  # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security#examples
  plug(Unplug,
    if: {Unplug.Predicates.RequestPathNotIn, ["/is_alive"]},
    do:
      {Plug.SSL,
       rewrite_on: [:x_forwarded_proto], expires: 63_072_000, subdomains: true, preload: true}
  )

  if Application.compile_env!(:guard, :environment) == :dev do
    use Plug.Debugger, otp_app: :guard
  end

  plug(Unplug,
    if: {Unplug.Predicates.AppConfigEquals, {:guard, :include_instance_config, true}},
    do: {Guard.Id.MaybeSetupGitProviders, []}
  )

  plug(Guard.Utils.Http.RequestLogger)
  plug(:plug_fetch_query_params)
  plug(:dynamic_plug_session)
  plug(:store_redirect_info)
  plug(:assign_user_info)
  plug(Ueberauth)

  plug(Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["text/*"]
  )

  plug(Plug.CSRFProtection)

  plug(:match)
  plug(:dispatch)

  @state_cookie_key "semaphore_auth_state"

  #
  # Health check for the Kubernetes Pod
  #

  get "/is_alive" do
    send_resp(conn, 200, "")
  end

  #
  # OAuth2
  #

  get "/oauth/:provider" when provider in ~w(github bitbucket gitlab) do
    conn
  end

  get "/oauth/:provider/callback" when provider in ~w(github bitbucket gitlab) do
    alias Guard.FrontRepo.RepoHostAccount

    case conn do
      %{assigns: %{user_id: nil}} ->
        send_resp(conn, 400, "User is not authenticated")

      %{assigns: %{user_id: user_id, ueberauth_failure: fails}} ->
        Logger.error(
          "Failed to authenticate user #{user_id} with #{fails.provider} #{inspect(fails.errors)}"
        )

        conn
        |> redirect(:noop, %{
          status: "error",
          message:
            "We're sorry, but your connection attempt was unsuccessful. Please try again. If you continue to experience issues, please contact our support team for assistance."
        })

      %{assigns: %{user_id: user_id, ueberauth_auth: auth}} ->
        {repo_host, repo_host_data} = extract_repo_host_data(auth)

        Logger.debug("Received auth data for #{repo_host} #{inspect(repo_host_data)}")

        case RepoHostAccount.update_repo_host_account(user_id, repo_host, repo_host_data,
               reset: false
             ) do
          {:ok, _} ->
            Guard.Events.UserUpdated.publish(user_id, "user_exchange", "updated")

            conn
            |> redirect(:noop, %{
              status: "success"
            })

          {:error, _} ->
            conn |> redirect(:noop)
        end
    end
  end

  defp extract_repo_host_data(auth) do
    {
      auth.provider,
      %{
        github_uid: auth.uid |> map_uid_to_string(),
        login: auth.info.nickname,
        name: auth.info.name || auth.info.nickname,
        permission_scope: auth.credentials.scopes |> Enum.join(","),
        token: auth.credentials.token,
        refresh_token: auth.credentials.refresh_token
      }
    }
  end

  defp map_uid_to_string(uid) when is_integer(uid), do: uid |> Integer.to_string()
  defp map_uid_to_string(uid), do: uid

  #
  # Root Login endpoint
  #
  get "/root/login" do
    ensure_empty_user(conn, fn ->
      if Application.get_env(:guard, :root_login) do
        conn |> login_page("root")
      else
        Logger.info("Root login is disabled")

        conn |> error_login_page("Root login is disabled")
      end
    end)
  end

  #
  # Signup endpoint
  #
  get "/signup" do
    logged_in = conn.assigns[:user_id] != nil

    case default_login_method() do
      method when method in ["local", "oidc"] ->
        conn |> signup_page(method, logged_in)

      unknown ->
        Logger.error("Unknown default signup method: #{unknown}")
        conn |> error_login_page("Signup is disabled")
    end
  end

  defp signup_page(conn, "local", logged_in) do
    conn
    |> render_signup_page(
      github: id_page("github"),
      bitbucket: id_page("bitbucket"),
      gitlab: id_page("gitlab") |> filter_gitlab(),
      logged_in: logged_in,
      me_url: me_page()
    )
  end

  defp signup_page(conn, "oidc", logged_in) do
    if Guard.OIDC.enabled?() do
      oidc_callback = id_page("oidc/callback")

      case Guard.OIDC.authorization_uri(oidc_callback) do
        {:ok, {state, verifier, url}} ->
          conn
          |> Guard.Utils.Http.put_state_value(@state_cookie_key, {state, verifier})
          |> render_signup_page(
            github: "#{url}&kc_idp_hint=github",
            bitbucket: "#{url}&kc_idp_hint=bitbucket",
            gitlab: "#{url}&kc_idp_hint=gitlab" |> filter_gitlab(),
            logged_in: logged_in,
            me_url: me_page()
          )

        {:error, error} ->
          Logger.error("Error occurred while fetching authorization uri: #{inspect(error)}")

          conn
          |> error_login_page("Error occurred while fetching authorization uri")
      end
    else
      Logger.info("OIDC configuration is missing")
      conn |> error_login_page("OIDC configuration is missing")
    end
  end

  # sobelow_skip ["XSS.SendResp"]
  defp render_signup_page(conn, assigns) do
    assigns =
      Keyword.merge(assigns,
        posthog_api_key: Application.get_env(:guard, :posthog_api_key, ""),
        posthog_host: Application.get_env(:guard, :posthog_host, "https://app.posthog.com")
      )

    html_content = Guard.TemplateRenderer.render_template([assigns: assigns], "signup.html")

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html_content)
  end

  #
  # Login endpoint
  #
  get "/login" do
    ensure_empty_user(conn, fn ->
      case conn.query_params["org_id"] do
        nil -> default_login_page(conn)
        org_id -> organization_login_page(conn, org_id)
      end
    end)
  end

  defp default_login_page(conn) do
    case default_login_method() do
      "saml" ->
        conn |> saml_login_page()

      method when method in ["local", "oidc"] ->
        conn |> login_page(method)

      unknown ->
        Logger.error("Unknown default login method: #{unknown}")

        conn |> error_login_page("Unknown default login method")
    end
  end

  defp organization_login_page(conn, org_id) do
    case Guard.Api.Organization.fetch(org_id) do
      nil ->
        Logger.error("Organization with id #{org_id} not found")

        conn |> default_login_page()

      org ->
        cond do
          Enum.member?(org.allowed_id_providers, "okta") ->
            conn |> saml_login_page(org.org_id)

          Enum.member?(org.allowed_id_providers, "oidc") ->
            conn |> login_page("oidc")

          true ->
            conn |> default_login_page()
        end
    end
  end

  defp saml_login_page(conn, org_id \\ nil) do
    case fetch_saml_sso_url(org_id) do
      nil ->
        conn
        |> error_login_page(
          "Single sign-on with SAML configuration is required. Please contact the organization owner to set it up to enable login."
        )

      sso_url ->
        conn |> Guard.Utils.Http.redirect_to_url(sso_url)
    end
  end

  defp login_page(conn, "root") do
    methods = Application.get_env(:guard, :root_login_methods)

    assigns =
      Enum.reduce(methods, [], fn method, acc ->
        case method do
          "github" ->
            Keyword.merge(acc, github: id_page("github"))

          "bitbucket" ->
            Keyword.merge(acc, bitbucket: id_page("bitbucket"))

          "gitlab" ->
            Keyword.merge(acc, gitlab: id_page("gitlab") |> filter_gitlab())

          _ ->
            acc
        end
      end)

    conn
    |> render_login_page(assigns)
  end

  defp login_page(conn, "local") do
    conn
    |> render_login_page(
      github: id_page("github"),
      bitbucket: id_page("bitbucket"),
      gitlab: id_page("gitlab") |> filter_gitlab()
    )
  end

  defp login_page(conn, "oidc") do
    if Guard.OIDC.enabled?() do
      oidc_callback = id_page("oidc/callback")

      case Guard.OIDC.authorization_uri(oidc_callback) do
        {:ok, {state, verifier, url}} ->
          conn
          |> Guard.Utils.Http.put_state_value(@state_cookie_key, {state, verifier})
          |> render_login_page(url)

        {:error, error} ->
          Logger.error("Error occurred while fetching authorization uri: #{inspect(error)}")

          conn
          |> error_login_page("Error occurred while fetching authorization uri")
      end
    else
      Logger.info("OIDC configuration is missing")
      conn |> error_login_page("OIDC configuration is missing")
    end
  end

  defp render_login_page(conn, url) when is_binary(url) do
    if Application.get_env(:guard, :keycloak_login_page) do
      conn
      |> Guard.Utils.Http.redirect_to_url(url)
    else
      conn
      |> render_login_page(
        github: "#{url}&kc_idp_hint=github",
        bitbucket: "#{url}&kc_idp_hint=bitbucket",
        gitlab: "#{url}&kc_idp_hint=gitlab" |> filter_gitlab()
      )
    end
  end

  # sobelow_skip ["XSS.SendResp"]
  defp render_login_page(conn, assigns) do
    assigns =
      Keyword.merge(assigns,
        posthog_api_key: Application.get_env(:guard, :posthog_api_key, ""),
        posthog_host: Application.get_env(:guard, :posthog_host, "https://app.posthog.com")
      )

    html_content = Guard.TemplateRenderer.render_template([assigns: assigns], "login.html")

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html_content)
  end

  defp error_login_page(conn, message) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, message)
  end

  #
  # When SAML is the default login method, it will return the SSO URL from the first organization, if it exists.
  # Otherwise checks if the given organization uses SAML and if they have set up an SSO URL.
  # Returns nil if both conditions are not met.
  #
  defp fetch_saml_sso_url(org_id) do
    alias Guard.Api.Okta

    fetched_okta_integrations =
      if default_login_method() == "saml" do
        Okta.fetch_for_first_org()
      else
        Okta.fetch_for_org(org_id)
      end

    fetched_okta_integration =
      Enum.find(fetched_okta_integrations, fn integration ->
        integration.sso_url != ""
      end)

    case fetched_okta_integration do
      %InternalApi.Okta.OktaIntegration{sso_url: sso_url} -> sso_url
      _ -> nil
    end
  rescue
    e ->
      Logger.error("Error occurred while fetching okta sso: #{inspect(e)}")
      nil
  end

  #
  # OIDC
  #
  get "/oidc/login" do
    ensure_empty_user(conn, fn ->
      conn |> login_page("oidc")
    end)
  end

  get "/oidc/callback" do
    if Guard.OIDC.enabled?() do
      oidc_callback = id_page("oidc/callback")

      code = conn.query_params["code"] || ""
      callback_state = conn.query_params["state"] || ""

      {:ok, {state, verifier}, conn} = Guard.Utils.Http.fetch_state_value(conn, @state_cookie_key)
      Guard.Utils.Http.delete_state_value(conn, @state_cookie_key)

      with :ok <- Guard.OIDC.state_match?(state, callback_state),
           {:ok, {user_data, tokens}} <-
             Guard.OIDC.exchange_code(code, verifier, oidc_callback),
           {:ok, user, mode} <- find_or_create_user(user_data),
           {:ok, id_token_enc} <- Guard.OIDC.Token.encrypt(tokens[:id_token], user.id),
           {:ok, refresh_token_enc} <- Guard.OIDC.Token.encrypt(tokens[:refresh_token], user.id),
           {:ok, remote_ip} <- get_remote_ip(conn),
           {:ok, user_agent} <- get_user_agent(conn),
           {:ok, session} <-
             Guard.Store.OIDCSession.create(%{
               user_id: user.id,
               id_token_enc: id_token_enc,
               refresh_token_enc: refresh_token_enc,
               expires_at: tokens[:expires_at],
               ip_address: remote_ip,
               user_agent: user_agent
             }) do
        Logger.info("[ID] User create a session user_id: #{user.id} session_id: #{session.id}")

        conn
        |> inject_session_cookie(session)
        |> update_redirect(mode)
        |> redirect(mode)
      else
        {:error, :invalid_state} ->
          Logger.warning("State mismatch: #{inspect(state)} != #{inspect(callback_state)}")

          conn |> Guard.Utils.Http.redirect_to_url(id_page())

        {:error, :user_blocked, user} ->
          Logger.warning("User #{user.id} is blocked")

          conn |> Guard.Utils.Http.redirect_to_url(id_page("blocked"))

        {:error, error} ->
          Logger.warning("Error during OIDC callback: #{inspect(error)}")

          conn |> Guard.Utils.Http.redirect_to_url(id_page())
      end
    else
      Logger.info("OIDC configuration is missing")
      conn |> Guard.Utils.Http.redirect_to_url(id_page())
    end
  end

  #
  # Blocked User
  #
  get "/blocked" do
    html_content = Guard.TemplateRenderer.render_template([], "blocked.html")

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html_content)
  end

  #
  # Logout
  #
  get "/logout" do
    assigns = [
      back_url: Guard.Utils.Http.validate_url(conn.query_params["back_url"], me_page()),
      csrf_token: Plug.CSRFProtection.get_csrf_token()
    ]

    html_content = Guard.TemplateRenderer.render_template([assigns: assigns], "logout.html")

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html_content)
  end

  post "/logout" do
    case conn |> get_session("id_provider") do
      "OIDC" ->
        handle_oidc_logout(conn)

      _ ->
        logout_redirect(conn)
    end
  end

  defp handle_oidc_logout(conn) do
    oidc_session_id = get_session(conn, "oidc_session_id")

    case Guard.Store.OIDCSession.get(oidc_session_id) do
      {:error, :not_found} ->
        logout_redirect(conn)

      {:ok, %{id_token_enc: nil} = session} ->
        Guard.Store.OIDCSession.expire(session)
        logout_redirect(conn)

      {:ok, session} ->
        Guard.Store.OIDCSession.expire(session)

        {:ok, id_token} = Guard.OIDC.Token.decrypt(session.id_token_enc, session.user_id)
        {:ok, redirect_url} = Guard.OIDC.end_session_uri(id_token, id_page())

        logout_redirect(conn, redirect_url)
    end
  end

  defp logout_redirect(conn, redirect_url \\ id_page()) do
    Logger.info("[ID] User destroyed a session user_id: #{conn.assigns.user_id}")

    conn
    |> clear_session()
    |> Guard.Utils.Http.redirect_to_url(redirect_url)
  end

  match "/" do
    query_string = conn.query_string
    login_path = if query_string != "", do: "login?#{query_string}", else: "login"

    conn
    |> Guard.Utils.Http.redirect_to_url(id_page(login_path))
  end

  #
  # Handle everything else as Not Found
  #
  match _ do
    send_resp(conn, 404, "Not Found")
  end

  ###
  ### Helper functions
  ###

  defp ensure_empty_user(conn, f) do
    case conn do
      %{assigns: %{user_id: nil}} -> f.()
      %{assigns: %{user_id: _}} -> conn |> Guard.Utils.Http.redirect_to_url(me_page())
    end
  end

  defp update_redirect(conn, :existing), do: conn

  defp update_redirect(conn, _),
    do: Guard.Utils.Http.store_redirect_info(conn, default_register_redirect())

  defp find_or_create_user(user_data) do
    case Guard.OIDC.User.find_user_by_oidc_id(user_data[:oidc_user_id]) do
      {:ok, user} ->
        case Guard.Store.User.Front.find(user.id) do
          {:ok, %Guard.FrontRepo.User{blocked_at: nil}} ->
            {:ok, user, :existing}

          {:ok, _} ->
            {:error, :user_blocked, user}

          {:error, :not_found} ->
            {:error, :user_not_found}
        end

      {:error, :not_found} ->
        case Guard.OIDC.User.create_with_oidc_data(user_data) do
          {:ok, user, :noop} ->
            {:ok, user, :registered}

          {:ok, user, mode} ->
            {:ok, user, mode}

          {:error, error} ->
            Logger.error(
              "Error occurred while adding user #{inspect(user_data)}: #{inspect(error)}"
            )

            {:error, :user_creation_error}
        end
    end
  end

  defp inject_session_cookie(conn, session) do
    secret_key_base = Application.get_env(:guard, :session_secret_key_base)
    conn = put_in(conn.secret_key_base, secret_key_base)

    conn
    |> put_session("oidc_session_id", session.id)
    |> put_session("id_provider", "OIDC")
  end

  defp redirect(conn, mode, query \\ %{})

  defp redirect(conn, :confirm_github, _) do
    conn
    |> Guard.Utils.Http.redirect_to_url(confirm_github_url())
  end

  defp redirect(conn, _, query) do
    url = Guard.Utils.Http.fetch_redirect_value(conn, default_redirect())

    conn
    |> Guard.Utils.Http.clear_redirect_value()
    |> Guard.Utils.Http.redirect_to_url(url, query: query)
  end

  defp get_user_agent(conn) do
    [user_agent] = get_req_header(conn, "user-agent")

    {:ok, user_agent}
  end

  defp get_remote_ip(conn) do
    {:ok, ip_tuple_to_string(conn.remote_ip)}
  end

  defp ip_tuple_to_string({a, b, c, d}) do
    Enum.join([a, b, c, d], ".")
  end

  defp ip_tuple_to_string(tuple) when tuple_size(tuple) == 8 do
    tuple
    |> Tuple.to_list()
    |> Enum.map_join(":", &Integer.to_string(&1, 16))
  end

  ###
  ### Plugs
  ###

  defp store_redirect_info(conn, _opts) do
    if conn.request_path =~ "login" or conn.request_path =~ "auth" do
      conn
      |> Guard.Utils.Http.store_redirect_info()
    else
      conn
    end
  end

  defp dynamic_plug_session(conn, opts) do
    conn = Guard.Session.setup(conn, opts)
    secret_key_base = Application.get_env(:guard, :session_secret_key_base)
    put_in(conn.secret_key_base, secret_key_base) |> fetch_session()
  end

  defp plug_fetch_query_params(conn, _opts) do
    if conn.request_path =~ "login" or conn.request_path =~ "callback" or
         conn.request_path =~ "auth" do
      conn |> fetch_query_params()
    else
      conn
    end
  end

  defp assign_user_info(conn, _opts) do
    user_id =
      conn
      |> get_req_header("x-semaphore-user-id")
      |> List.first()

    conn |> assign(:user_id, user_id)
  end

  defp me_page, do: "https://me.#{domain()}"
  defp id_page, do: "https://id.#{domain()}"
  defp id_page(path), do: "https://id.#{domain()}/#{path}"
  defp default_redirect, do: me_page()
  defp default_register_redirect, do: "https://me.#{domain()}?signup=true"
  defp domain, do: Application.get_env(:guard, :base_domain)

  defp confirm_github_url do
    "https://id.#{domain()}/oauth/github?scope=#{Guard.FrontRepo.RepoHostAccount.register_scope()}"
  end

  defp default_login_method, do: Application.get_env(:guard, :default_login_method)

  defp filter_gitlab(item) do
    if gitlab_enabled?(), do: item, else: nil
  end

  defp gitlab_enabled?, do: not Application.get_env(:guard, :hide_gitlab_login_page)
end
