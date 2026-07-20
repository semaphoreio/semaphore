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
    parsers: [:urlencoded, :json],
    pass: ["text/*"],
    json_decoder: Jason
  )

  plug(Unplug,
    if:
      {Unplug.Predicates.RequestPathNotIn,
       ["/mcp/oauth/register", "/mcp/oauth/token", "/cli/token", "/cli/device"]},
    do: {Plug.CSRFProtection, []}
  )

  plug(:match)
  plug(:dispatch)

  @state_cookie_key "semaphore_auth_state"
  @device_consent_cookie_key "semaphore_cli_device_consent"
  # Marks a browser that has completed the OIDC web sign-in during an
  # auth-first GET /device. The ext-auth edge injects x-semaphore-user-id only
  # on org hosts; the id host never gets it, so this marker is how the id host
  # recognises an authenticated browser (its absence is what caused the
  # /device -> OIDC redirect loop). Distinct key AND shape from the web-login
  # state, the device-authorization ctx, and the consent cookie.
  @device_authed_cookie_key "semaphore_cli_device_authed"
  # Server-side freshness bound for that marker. The cookie is AEAD-encrypted
  # with the same 30-minute max_age as the other state cookies; this issued_at
  # check keeps the marker genuinely short-lived regardless of client max_age.
  @device_authed_ttl_seconds 300

  #
  # Health check for the Kubernetes Pod
  #

  get "/is_alive" do
    send_resp(conn, 200, "")
  end

  #
  # MCP OAuth Server (Authorization Server endpoints)
  #

  forward("/mcp/oauth", to: Guard.McpOAuth.Server)

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
          code: "auth_failed",
          provider: to_string(fails.provider)
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

          {:error, reason} ->
            code = Guard.Id.OAuthErrorCode.from_reason(reason)

            Logger.error(
              "Failed to update RepoHostAccount user_id=#{user_id} provider=#{repo_host} " <>
                "code=#{code} kind=#{repo_host_error_kind(reason)}"
            )

            conn
            |> redirect(:noop, %{
              status: "error",
              code: code,
              provider: to_string(repo_host)
            })
        end
    end
  end

  defp repo_host_error_kind(:invalid_data), do: "invalid_data"

  defp repo_host_error_kind(%Ecto.Changeset{errors: errors}) do
    "changeset:" <> (errors |> Keyword.keys() |> Enum.map_join(",", &to_string/1))
  end

  defp repo_host_error_kind(_), do: "other"

  @doc false
  def parse_expires_at(nil), do: nil
  def parse_expires_at(%DateTime{} = dt), do: dt

  def parse_expires_at(expires_at) when is_integer(expires_at) do
    case DateTime.from_unix(expires_at, :second) do
      {:ok, dt} ->
        dt

      {:error, reason} ->
        Logger.warning(
          "Invalid expires_at integer from OAuth: #{inspect(expires_at)} (#{inspect(reason)})"
        )

        nil
    end
  end

  def parse_expires_at(other) do
    Logger.warning("Unexpected expires_at value from OAuth: #{inspect(other)}")
    nil
  end

  defp extract_repo_host_data(auth) do
    token_expires_at = parse_expires_at(auth.credentials.expires_at)

    {
      auth.provider,
      %{
        github_uid: auth.uid |> map_uid_to_string(),
        login: auth.info.nickname,
        name: pick_name(auth.info.name, auth.info.nickname),
        permission_scope: auth.credentials.scopes |> Enum.join(","),
        token: auth.credentials.token,
        refresh_token: auth.credentials.refresh_token,
        token_expires_at: token_expires_at
      }
    }
  end

  defp pick_name(name, nickname) when name in [nil, ""], do: nickname
  defp pick_name(name, _nickname), do: name

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
        posthog_host: Application.get_env(:guard, :posthog_host, "https://app.posthog.com"),
        google_gtm_id: Application.get_env(:guard, :google_gtm_id, "")
      )

    html_content = Guard.TemplateRenderer.render_template([assigns: assigns], "signup.html")

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html_content)
  end

  #
  # CLI device authorization request (RFC 8628) — the `sem-ai signin` entry point.
  # CSRF-exempt (see plug above); it's a direct CLI→guard call, not a browser form.
  # Captures the requester's IP / coarse geo / user-agent for the consent screen.
  #
  post "/cli/device" do
    if Guard.OIDC.enabled?() do
      {:ok, remote_ip} = get_remote_ip(conn)

      context = %{
        ip: remote_ip,
        geo: coarse_geo(conn),
        user_agent: conn |> get_req_header("user-agent") |> List.first()
      }

      case Guard.CLIAuth.request_device_authorization(context) do
        {:ok, response} ->
          cli_json(conn, 200, response)

        {:error, error} ->
          Logger.error("CLI device authorization failed: #{inspect(error)}")
          cli_json(conn, 500, %{error: "server_error"})
      end
    else
      cli_json(conn, 400, %{error: "oidc_disabled"})
    end
  end

  #
  # CLI token exchange — trade a polled device_code for an API token.
  # CSRF-exempt (see plug above); direct CLI→guard.
  #
  post "/cli/token" do
    params = conn.body_params || %{}

    case params["grant_type"] do
      "urn:ietf:params:oauth:grant-type:device_code" ->
        handle_device_token(conn, params)

      _ ->
        cli_json(conn, 400, %{error: "unsupported_grant_type"})
    end
  end

  defp handle_device_token(conn, params) do
    case Guard.CLIAuth.poll_device_token(params["device_code"] || "") do
      {:ok, token, action} ->
        # host is nil: a fresh account has no org yet (the CLI keeps its own
        # host argument). token_action tells the CLI whether this was a fresh
        # mint ("minted", new account) or a consented reset ("rotated").
        cli_json(conn, 200, %{token: token, host: nil, token_action: action})

      {:error, :token_exists} ->
        cli_json(conn, 409, token_exists_body())

      # RFC 8628 §3.5 polling states — HTTP 400 with a distinguishable error code.
      {:error, reason}
      when reason in [:authorization_pending, :slow_down, :access_denied, :expired_token] ->
        cli_json(conn, 400, %{error: to_string(reason)})

      _ ->
        cli_json(conn, 400, %{error: "invalid_grant"})
    end
  end

  # Consent said "mint" (the account had no token when approved) but a token
  # appeared before the poll redeemed the code. Never escalate that consent
  # into a rotation — tell the CLI to start over.
  defp token_exists_body do
    %{
      error: "token_exists",
      message:
        "This account received an API token while sign-in was in progress. " <>
          "Run `sem-ai signin` again to confirm what to do with it."
    }
  end

  #
  # Device verification page (RFC 8628) — where the human enters the user_code,
  # signs in via the OIDC web flow, and lands on the consent screen.
  #
  get "/device" do
    conn = fetch_query_params(conn)

    prefill =
      case conn.query_params["user_code"] do
        p when is_binary(p) -> p
        _ -> ""
      end

    # Precedence:
    #
    #   1. A device authorization parked mid-flow in the state cookie (the
    #      code POST stashes it before redirecting to the IdP) resumes its
    #      sign-in continuation - session or not.
    #   2. Otherwise the page is auth-first: an authenticated browser gets the
    #      code-entry form, an anonymous one is sent to the OIDC sign-in first
    #      and returns here afterwards (see start_device_return_oidc).
    #
    # Authentication is asserted by EITHER the x-semaphore-user-id header the
    # ext-auth edge injects on org hosts OR a valid, unexpired device-auth
    # marker cookie set by the device_return callback. The id host never gets
    # that header, so gating on it alone looped /device -> OIDC forever;
    # device_session/2 checks both. Entering the code stays an explicit POST
    # in every branch - auth-first never consumes a code from the URL.
    case parked_device_authorization(conn, prefill) do
      {:resume, row, user_code_display, conn} ->
        resume_device_oidc(conn, row, user_code_display)

      {:expired, conn} ->
        conn
        |> Guard.Utils.Http.delete_state_value(@state_cookie_key)
        |> device_entry_or_signin(prefill,
          error:
            "That sign-in request expired. Start a new one from your terminal " <>
              "and enter the new code."
        )

      {:none, conn} ->
        device_entry_or_signin(conn, prefill, [])
    end
  end

  # Auth-first terminal for GET /device: render the code-entry form for an
  # authenticated browser, or start the sign-in-first redirect for an
  # anonymous one. `opts` (e.g. an :error hint) only reaches the rendered
  # form; the redirect branch carries just the prefill.
  defp device_entry_or_signin(conn, prefill, opts) do
    case device_session(conn, prefill) do
      {:authed, conn} ->
        device_entry_page(conn, 200, Keyword.put(opts, :prefill, prefill))

      {:anonymous, conn} ->
        start_device_return_oidc(conn, prefill)
    end
  end

  # May this browser see the code-entry form without a sign-in first?
  #
  #   * the ext-auth edge injected x-semaphore-user-id (org hosts), or
  #   * a valid, unexpired device-auth marker cookie whose prefill matches
  #     this request (the id host - set by the device_return callback).
  #
  # A genuinely different explicit ?user_code= is a fresh sign-in attempt and
  # does NOT ride a stale marker (mirrors the parked-flow prefill rule).
  defp device_session(conn, prefill) do
    if conn.assigns[:user_id] do
      {:authed, conn}
    else
      case fetch_device_authed_marker(conn, prefill) do
        {:ok, conn} -> {:authed, conn}
        {:none, conn} -> {:anonymous, conn}
      end
    end
  end

  # Resolves what a GET /device should do with the state cookie:
  #
  #   * `{:resume, row, display, conn}` - a device flow is parked and its row
  #     is still pending and unexpired; continue to the IdP.
  #   * `{:expired, conn}` - the parked row is pending but past expires_at;
  #     the caller drops the stale cookie and re-renders the form with a hint.
  #   * `{:none, conn}` - no parked device flow (no cookie, a normal web-login
  #     OIDC state, a consumed/denied row, or an explicit ?user_code= for a
  #     DIFFERENT code); render the entry form as before.
  #
  # The signed state cookie remains the only carrier of flow state - nothing
  # is read from the URL beyond the pre-existing prefill, and resuming
  # re-issues a fresh OIDC state/verifier exactly like the code POST does.
  defp parked_device_authorization(conn, prefill) do
    case Guard.Utils.Http.fetch_state_value(conn, @state_cookie_key) do
      {:ok, {_state, _verifier, %{device_row_id: row_id, user_code_display: display}}, conn} ->
        if prefill_matches?(prefill, display) do
          resolve_parked_device_row(conn, row_id, display)
        else
          # An explicitly supplied different code wins over the parked flow.
          {:none, conn}
        end

      {:ok, _other, conn} ->
        {:none, conn}

      _ ->
        {:none, conn}
    end
  end

  defp resolve_parked_device_row(conn, row_id, display) do
    case Guard.Store.CliAuthCode.get_device(row_id) do
      {:ok, %{status: "pending"} = row} ->
        if DateTime.compare(DateTime.utc_now(), row.expires_at) == :lt do
          {:resume, row, display, conn}
        else
          {:expired, conn}
        end

      _ ->
        # Consumed, denied, or gone: this sign-in already reached a terminal
        # state elsewhere; fall back to the plain entry form.
        {:none, conn}
    end
  end

  # An empty prefill is a plain revisit; a non-empty one only resumes the
  # parked flow when it is the same code (compared normalized).
  defp prefill_matches?("", _display), do: true

  defp prefill_matches?(prefill, display) do
    Guard.Store.CliAuthCode.normalize_user_code(prefill) ==
      Guard.Store.CliAuthCode.normalize_user_code(display)
  end

  post "/device" do
    user_code = (conn.body_params || %{})["user_code"] || ""

    if Guard.OIDC.enabled?() do
      {:ok, remote_ip} = get_remote_ip(conn)

      case Guard.CLIAuth.verify_user_code(user_code, remote_ip) do
        {:ok, row} ->
          start_device_oidc(conn, row, user_code)

        {:error, :rate_limited} ->
          device_entry_page(conn, 429,
            prefill: user_code,
            error: "Too many attempts right now. Please wait a minute and try again."
          )

        {:error, :too_many_attempts} ->
          device_entry_page(conn, 400,
            error:
              "That code was entered too many times and is no longer valid. " <>
                "Start a new sign-in from your terminal."
          )

        {:error, :invalid_user_code} ->
          device_entry_page(conn, 400,
            prefill: user_code,
            error: "That code is invalid or has expired. Check your terminal and try again."
          )
      end
    else
      conn |> error_login_page("OIDC configuration is missing")
    end
  end

  post "/device/decision" do
    decision = (conn.body_params || %{})["decision"]

    case Guard.Utils.Http.fetch_state_value(conn, @device_consent_cookie_key) do
      {:ok, {row_id, user_id, shown_action, user_code_display}, conn} ->
        # Reaching a decision consumes the device authorization; drop both the
        # consent cookie and the (now spent) device-auth marker.
        conn =
          conn
          |> Guard.Utils.Http.delete_state_value(@device_consent_cookie_key)
          |> Guard.Utils.Http.delete_state_value(@device_authed_cookie_key)

        ctx = %{
          row_id: row_id,
          user_id: user_id,
          shown_action: shown_action,
          user_code_display: user_code_display
        }

        handle_device_decision(conn, decision, ctx)

      _ ->
        device_message_page(
          conn,
          "Session expired",
          "Your approval session expired. Return to your terminal and start again."
        )
    end
  end

  defp handle_device_decision(conn, "approve", ctx) do
    # The click is the authoritative consent moment: what the user approved
    # must be exactly what gets recorded on the row. If the account's token
    # state changed while the consent page was open (say, a parallel sign-in
    # minted a token), the wording they read no longer matches the action —
    # re-ask with the right wording instead of silently recording a stronger
    # action than the one they consented to.
    actual_action = Guard.CLIAuth.intended_token_action(ctx.user_id)

    if actual_action == ctx.shown_action do
      record_device_approval(conn, ctx, actual_action)
    else
      reprompt_device_consent(conn, ctx, actual_action)
    end
  end

  defp handle_device_decision(conn, _deny, ctx) do
    Guard.CLIAuth.deny_device(ctx.row_id)

    message =
      case ctx.shown_action do
        "rotate" ->
          "Nothing was authorized and your API token was not changed. " <>
            "It is safe to close this window."

        _ ->
          "Nothing was authorized. It is safe to close this window."
      end

    device_message_page(conn, "Request denied", message)
  end

  defp record_device_approval(conn, ctx, action) do
    case Guard.CLIAuth.approve_device(ctx.row_id, ctx.user_id, action) do
      {:ok, :approved} ->
        message =
          case action do
            "rotate" ->
              "You can return to your terminal. Your API token is reset as the tool " <>
                "finishes signing in. Anything still using the previous token " <>
                "(CI secrets, scripts, other machines) will need the new one."

            _ ->
              "You can return to your terminal. The command-line tool finishes " <>
                "signing in automatically."
          end

        device_message_page(conn, "Device authorized", message)

      {:error, _} ->
        device_message_page(
          conn,
          "Request expired",
          "This request expired before it was approved. Start a new sign-in from your terminal."
        )
    end
  end

  defp reprompt_device_consent(conn, ctx, actual_action) do
    case Guard.Store.CliAuthCode.get_device(ctx.row_id) do
      {:ok, %{status: "pending"} = row} ->
        consent = {row.id, ctx.user_id, actual_action, ctx.user_code_display}

        conn
        |> Guard.Utils.Http.put_state_value(@device_consent_cookie_key, consent)
        |> render_device_consent_page(row, ctx.user_code_display, actual_action, reprompt: true)

      _ ->
        device_message_page(
          conn,
          "Request expired",
          "This request expired before it was approved. Start a new sign-in from your terminal."
        )
    end
  end

  defp start_device_oidc(conn, row, raw_user_code) do
    user_code_display =
      raw_user_code
      |> Guard.Store.CliAuthCode.normalize_user_code()
      |> Guard.Store.CliAuthCode.format_user_code()

    resume_device_oidc(conn, row, user_code_display)
  end

  # Redirects into the OIDC sign-in for a device row, parking the device
  # context in the state cookie. Used both when the code is first submitted
  # (start_device_oidc) and when GET /device resumes a parked pending flow -
  # each call issues a fresh state/verifier pair, replacing any previous one.
  defp resume_device_oidc(conn, row, user_code_display) do
    oidc_callback = id_page("oidc/callback")

    case Guard.OIDC.authorization_uri(oidc_callback) do
      {:ok, {state, verifier, url}} ->
        # Ride the device context inside the single OIDC state cookie (3-tuple),
        # per-flow and gated by state_match.
        ctx = %{device_row_id: row.id, user_code_display: user_code_display}

        conn
        |> Guard.Utils.Http.put_state_value(@state_cookie_key, {state, verifier, ctx})
        |> Guard.Utils.Http.redirect_to_url(url)

      {:error, error} ->
        Logger.error("CLI device OIDC authorization_uri error: #{inspect(error)}")
        conn |> error_login_page("Error occurred while fetching authorization uri")
    end
  end

  # Auth-first: an anonymous GET /device is sent to the OIDC sign-in before the
  # code-entry page is shown. The state cookie carries a `device_return` ctx
  # (a shape distinct from both the web-login 2-tuple and the device
  # authorization's `device_row_id` ctx), so the callback knows to finish by
  # landing back on the code-entry page - prefill included. The prefill rides
  # the encrypted cookie, never the IdP round trip.
  defp start_device_return_oidc(conn, prefill) do
    oidc_callback = id_page("oidc/callback")

    case Guard.OIDC.authorization_uri(oidc_callback) do
      {:ok, {state, verifier, url}} ->
        ctx = %{device_return: true, user_code_prefill: prefill}

        conn
        |> Guard.Utils.Http.put_state_value(@state_cookie_key, {state, verifier, ctx})
        |> Guard.Utils.Http.redirect_to_url(url)

      {:error, error} ->
        Logger.error("CLI device return OIDC authorization_uri error: #{inspect(error)}")
        conn |> error_login_page("Error occurred while fetching authorization uri")
    end
  end

  # Clean id-host URL the device_return callback redirects to once the marker
  # is set: back on /device with the (non-secret) user_code re-attached. A
  # refresh of this URL is a harmless GET, unlike sitting on
  # /oidc/callback?code=... which would replay the one-time OIDC code.
  defp device_return_url(prefill) when is_binary(prefill) and prefill != "" do
    id_page("device") <> "?" <> URI.encode_query(%{"user_code" => prefill})
  end

  defp device_return_url(_prefill), do: id_page("device")

  # Sets the short-lived, AEAD-encrypted marker recording that this browser
  # just completed the OIDC web sign-in. It asserts "this browser is signed in"
  # only - no user identity is stored, and the token mint/rotate still requires
  # the code POST and the consent decision (identity is re-established there via
  # the device-authorization OIDC callback).
  defp put_device_authed_marker(conn, prefill) do
    marker = %{
      device_authed: true,
      user_code_prefill: prefill,
      issued_at: DateTime.utc_now() |> DateTime.to_unix()
    }

    Guard.Utils.Http.put_state_value(conn, @device_authed_cookie_key, marker)
  end

  # Reads the device-auth marker. Honoured only when it is well-shaped, still
  # within @device_authed_ttl_seconds, and its prefill matches this request
  # (an empty request prefill matches any marker; a different explicit code
  # does not, so a stale marker cannot short-circuit a brand-new sign-in).
  defp fetch_device_authed_marker(conn, prefill) do
    case Guard.Utils.Http.fetch_state_value(conn, @device_authed_cookie_key) do
      {:ok,
       %{
         device_authed: true,
         user_code_prefill: marker_prefill,
         issued_at: issued_at
       }, conn} ->
        if device_marker_fresh?(issued_at) and prefill_matches?(prefill, marker_prefill) do
          {:ok, conn}
        else
          {:none, conn}
        end

      {:ok, _other, conn} ->
        {:none, conn}

      _ ->
        {:none, conn}
    end
  end

  defp device_marker_fresh?(issued_at) when is_integer(issued_at) do
    (DateTime.utc_now() |> DateTime.to_unix()) - issued_at <= @device_authed_ttl_seconds
  end

  defp device_marker_fresh?(_), do: false

  # sobelow_skip ["XSS.SendResp"]
  defp cli_json(conn, status, body) do
    conn
    |> put_resp_header("content-type", "application/json")
    # RFC 8628 §3.2 / §3.4 MUST: /cli/device and /cli/token responses carry
    # device_code, user_code, and tokens — never cache them.
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(status, Jason.encode!(body))
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

    if Guard.OIDC.enabled?() do
      root_oidc_login(conn, methods)
    else
      root_local_login(conn, methods)
    end
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

  defp root_oidc_login(conn, _methods) do
    oidc_callback = id_page("oidc/callback")

    case Guard.OIDC.authorization_uri(oidc_callback) do
      {:ok, {state, verifier, url}} ->
        conn
        |> Guard.Utils.Http.put_state_value(@state_cookie_key, {state, verifier})
        |> render_login_page(github: "#{url}&kc_idp_hint=github")

      {:error, error} ->
        Logger.error("Error occurred while fetching authorization uri: #{inspect(error)}")

        conn
        |> error_login_page("Error occurred while fetching authorization uri")
    end
  end

  defp root_local_login(conn, methods) do
    assigns =
      Enum.reduce(methods, [], fn method, acc ->
        case method do
          "github" ->
            Keyword.merge(acc, github: id_page("oauth/github"))

          "bitbucket" ->
            Keyword.merge(acc, bitbucket: id_page("oauth/bitbucket"))

          "gitlab" ->
            Keyword.merge(acc, gitlab: id_page("oauth/gitlab") |> filter_gitlab())

          _ ->
            acc
        end
      end)

    conn
    |> render_login_page(assigns)
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
        posthog_host: Application.get_env(:guard, :posthog_host, "https://app.posthog.com"),
        google_gtm_id: Application.get_env(:guard, :google_gtm_id, "")
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
    case oidc_flow_kind(conn) do
      :device ->
        handle_cli_oidc_callback(conn)

      {:device_return, prefill} ->
        handle_device_return_oidc_callback(conn, prefill)

      :browser ->
        handle_browser_oidc_callback(conn)
    end
  end

  # The flow a callback belongs to is identified by the SHAPE of the OIDC state
  # cookie (not a separate persistent cookie), so each flow is self-contained: a
  # new login overwrites it, the callback consumes it, and state_match still
  # gates it.
  #
  #   * {state, verifier, %{device_row_id: ...}} - CLI device authorization
  #     continuation (code already entered); ends on the consent page.
  #   * {state, verifier, %{device_return: true, ...}} - auth-first /device
  #     visit; a normal web sign-in that finishes back on the code-entry page.
  #   * {state, verifier} - normal web login.
  defp oidc_flow_kind(conn) do
    case Guard.Utils.Http.fetch_state_value(conn, @state_cookie_key) do
      {:ok, {_state, _verifier, %{device_row_id: _}}, _conn} ->
        :device

      {:ok, {_state, _verifier, %{device_return: true} = ctx}, _conn} ->
        {:device_return, Map.get(ctx, :user_code_prefill, "")}

      _ ->
        :browser
    end
  end

  defp handle_cli_oidc_callback(conn) do
    case Guard.Utils.Http.fetch_state_value(conn, @state_cookie_key) do
      {:ok, {_state, _verifier, %{device_row_id: _} = ctx}, conn} ->
        handle_device_oidc_callback(conn, ctx)

      _ ->
        handle_browser_oidc_callback(conn)
    end
  end

  # Device grant: the human has entered the user_code and signed in. Establish
  # identity via the OIDC exchange, then show the consent screen. The device
  # row id + authenticated user_id are stashed in a signed cookie so the
  # consent POST cannot forge who is approving.
  defp handle_device_oidc_callback(conn, ctx) do
    oidc_callback = id_page("oidc/callback")
    code = conn.query_params["code"] || ""
    callback_state = conn.query_params["state"] || ""

    with {:ok, {state, verifier, _ctx}, conn} <-
           Guard.Utils.Http.fetch_state_value(conn, @state_cookie_key),
         conn = Guard.Utils.Http.delete_state_value(conn, @state_cookie_key),
         :ok <- Guard.OIDC.state_match?(state, callback_state),
         {:ok, {user_data, _tokens}} <- Guard.OIDC.exchange_code(code, verifier, oidc_callback),
         {:ok, allowed, error_message} <- verify_oidc_login_allowed(user_data),
         true <- allowed || {:error, :login_not_allowed, error_message},
         {:ok, user, _mode} <- find_or_create_user(user_data),
         {:ok, %{status: "pending"} = row} <-
           Guard.Store.CliAuthCode.get_device(ctx.device_row_id) do
      Logger.info("[ID] CLI device sign-in complete, showing consent for user_id: #{user.id}")

      # The consent wording depends on whether the account already has a token
      # ("rotate" = explicit reset consent) or not ("mint"). The action shown
      # rides in the signed cookie and is re-checked at decision time, so the
      # recorded consent can never be stronger than the wording that was read.
      token_action = Guard.CLIAuth.intended_token_action(user.id)
      consent = {row.id, user.id, token_action, ctx.user_code_display}

      conn
      |> Guard.Utils.Http.put_state_value(@device_consent_cookie_key, consent)
      |> render_device_consent_page(row, ctx.user_code_display, token_action)
    else
      error ->
        Logger.warning("CLI device OIDC callback failed: #{inspect(error)}")

        device_message_page(
          conn,
          "Sign-in failed",
          "We couldn't complete sign-in for this request. Return to your terminal and try again."
        )
    end
  end

  # Auth-first /device return: the anonymous visitor was bounced to the OIDC
  # sign-in and is now back. We only confirm the web sign-in succeeded (account
  # exists, allowed, not blocked) - NOT a standing app session: no session cookie
  # is set, only the short-lived device-auth marker (keeps the browser footprint
  # to "can approve"). Then 302 to a clean /device?user_code=<prefill> URL so a
  # refresh is a harmless GET; rendering the form in place would leave the browser
  # on /oidc/callback?code=... and replay the one-time OIDC code on reload.
  defp handle_device_return_oidc_callback(conn, prefill) do
    if Guard.OIDC.enabled?() do
      oidc_callback = id_page("oidc/callback")
      code = conn.query_params["code"] || ""
      callback_state = conn.query_params["state"] || ""

      with {:ok, {state, verifier, _ctx}, conn} <-
             Guard.Utils.Http.fetch_state_value(conn, @state_cookie_key),
           conn = Guard.Utils.Http.delete_state_value(conn, @state_cookie_key),
           :ok <- Guard.OIDC.state_match?(state, callback_state),
           {:ok, {user_data, _tokens}} <- Guard.OIDC.exchange_code(code, verifier, oidc_callback),
           {:ok, allowed, error_message} <- verify_oidc_login_allowed(user_data),
           true <- allowed || {:error, :login_not_allowed, error_message},
           {:ok, _user, _mode} <- find_or_create_user(user_data) do
        conn
        |> put_device_authed_marker(prefill)
        |> Guard.Utils.Http.redirect_to_url(device_return_url(prefill))
      else
        error ->
          Logger.warning("CLI device return OIDC callback failed: #{inspect(error)}")

          # A device-specific page, never bare /login: the user was mid device
          # sign-in and should be told to retry from the terminal.
          device_message_page(
            conn,
            "Sign-in failed",
            "We couldn't complete sign-in for this request. Return to your terminal and try again."
          )
      end
    else
      Logger.info("OIDC configuration is missing")
      conn |> Guard.Utils.Http.redirect_to_url(id_page())
    end
  end

  #
  # Device-grant HTML pages. Rendered as inline HTML (mirrors the MCP OAuth
  # consent screen); all interpolated, user-controlled values are html_escaped.
  #

  # sobelow_skip ["XSS.SendResp"]
  defp device_entry_page(conn, status, opts) do
    prefill = Keyword.get(opts, :prefill, "")
    error = Keyword.get(opts, :error)

    error_html = if error, do: ~s(<p class="error">#{html_escape(error)}</p>), else: ""

    html = """
    #{device_page_head("Connect a command-line tool")}
      <div class="container">
        <h1>Connect a command-line tool</h1>
        <p>Enter the code shown in your terminal to continue. You'll sign in to
           Semaphore (or create an account), then review exactly what you
           are authorizing.</p>
        #{error_html}
        <form action="/device" method="post">
          <input type="hidden" name="_csrf_token" value="#{Plug.CSRFProtection.get_csrf_token()}" />
          <label for="user_code">Code</label>
          <input id="user_code" name="user_code" value="#{html_escape(prefill)}"
                 autocomplete="off" autocapitalize="characters" spellcheck="false"
                 placeholder="XXXX-XXXX" />
          <button type="submit">Continue</button>
        </form>
      </div>
    #{device_page_foot()}
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(status, html)
  end

  # sobelow_skip ["XSS.SendResp"]
  defp render_device_consent_page(conn, row, user_code_display, token_action, opts \\ []) do
    reprompt_html =
      if opts[:reprompt] do
        ~s(<p class="error">Your account changed while this page was open. ) <>
          ~s(Review the updated details below before deciding.</p>)
      else
        ""
      end

    {title, action_html, approve_label} =
      case token_action do
        "rotate" ->
          {"Reset your API token?",
           """
           <p class="warning"><strong>This account already has an API token.</strong>
              Approving generates a new token for this command-line tool and
              <strong>your current token stops working immediately, everywhere it is
              used</strong>: CI secrets, scripts, other machines, and any other
              integration authenticated with it will need the new token.</p>
           """, "Reset token and authorize"}

        _ ->
          {"Authorize a command-line tool",
           """
           <p>Approving creates the API token for this account and hands it to the
              command-line tool.</p>
           """, "Approve"}
      end

    html = """
    #{device_page_head(title)}
      <div class="container">
        <h1>#{html_escape(title)}</h1>
        #{reprompt_html}
        <p>You are authorizing a <strong>command-line tool on a device to act as YOU</strong>
           on Semaphore. This is not a normal website login.</p>
        #{action_html}
        <div class="details">
          <div><span>Code</span><code>#{html_escape(user_code_display)}</code></div>
          <div><span>Requested from IP</span><code>#{html_escape(row.requester_ip)}</code></div>
          <div><span>Location</span><code>#{html_escape(row.requester_geo || "Unknown")}</code></div>
          <div><span>Device</span><code>#{html_escape(row.requester_user_agent || "Unknown")}</code></div>
        </div>

        <p class="warning">Only continue if you started this on your own machine.
           If someone sent you this code, stop and click Deny.</p>

        <form action="/device/decision" method="post">
          <input type="hidden" name="_csrf_token" value="#{Plug.CSRFProtection.get_csrf_token()}" />
          <div class="buttons">
            <button type="submit" name="decision" value="deny" class="deny">#{if token_action == "rotate", do: "Keep current token", else: "Deny"}</button>
            <button type="submit" name="decision" value="approve" class="approve">#{approve_label}</button>
          </div>
        </form>
      </div>
    #{device_page_foot()}
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html)
  end

  # sobelow_skip ["XSS.SendResp"]
  defp device_message_page(conn, title, message) do
    html = """
    #{device_page_head(title)}
      <div class="container">
        <h1>#{html_escape(title)}</h1>
        <p>#{html_escape(message)}</p>
      </div>
    #{device_page_foot()}
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html)
  end

  defp device_page_head(title) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>#{html_escape(title)}</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 40px; background: #f5f5f5; color: #222; }
        .container { max-width: 520px; margin: 0 auto; background: #fff; padding: 32px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.08); }
        h1 { font-size: 22px; margin-top: 0; }
        label { display: block; font-weight: 600; margin: 16px 0 6px; }
        input[type=text], input:not([type]) { width: 100%; padding: 12px; font-size: 18px; letter-spacing: 4px; text-align: center; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }
        button { margin-top: 20px; padding: 12px 24px; border: none; border-radius: 4px; font-size: 15px; cursor: pointer; }
        button[type=submit] { background: #19a974; color: #fff; }
        .details { background: #f8f9fa; border-radius: 6px; padding: 8px 16px; margin: 20px 0; }
        .details div { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; gap: 16px; }
        .details div:last-child { border-bottom: none; }
        .details span { color: #666; }
        .details code { word-break: break-all; text-align: right; }
        .warning { background: #fff4e5; border: 1px solid #ffd8a8; border-radius: 6px; padding: 12px 16px; color: #8a5300; }
        .error { background: #ffe3e3; border: 1px solid #ffc9c9; border-radius: 6px; padding: 12px 16px; color: #a61e1e; }
        .buttons { display: flex; gap: 12px; margin-top: 24px; }
        .buttons button { flex: 1; }
        .buttons .deny { background: #f1f3f5; color: #333; }
        .buttons .approve { background: #19a974; color: #fff; }
      </style>
    </head>
    <body>
    """
  end

  defp device_page_foot, do: "</body></html>"

  # Coarse geo comes from an upstream country header (Cloudflare's cf-ipcountry
  # or an equivalent injected at the edge). guard has no geolocation library, so
  # when the header is absent the consent screen shows "Unknown".
  defp coarse_geo(conn) do
    (get_req_header(conn, "cf-ipcountry") ++ get_req_header(conn, "x-geo-country"))
    |> List.first()
  end

  defp html_escape(nil), do: ""

  defp html_escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp html_escape(value), do: value |> to_string() |> html_escape()

  defp handle_browser_oidc_callback(conn) do
    if Guard.OIDC.enabled?() do
      oidc_callback = id_page("oidc/callback")

      code = conn.query_params["code"] || ""
      callback_state = conn.query_params["state"] || ""

      with {:ok, {state, verifier}, conn} <-
             Guard.Utils.Http.fetch_state_value(conn, @state_cookie_key),
           :ok <- Guard.OIDC.state_match?(state, callback_state),
           {:ok, {user_data, tokens}} <-
             Guard.OIDC.exchange_code(code, verifier, oidc_callback),
           {:ok, allowed, error_message} <- verify_oidc_login_allowed(user_data),
           true <- allowed || {:error, :login_not_allowed, error_message},
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

        # Genuinely drop the consumed state cookie (the previous code discarded
        # delete_state_value/2's return, leaving it live); thread it through so
        # the successful response actually clears it.
        conn
        |> Guard.Utils.Http.delete_state_value(@state_cookie_key)
        |> inject_session_cookie(session)
        |> update_redirect(mode)
        |> redirect(mode)
      else
        {:error, :invalid_state} ->
          Logger.warning("State mismatch on OIDC callback: #{inspect(callback_state)}")

          conn |> Guard.Utils.Http.redirect_to_url(id_page())

        {:error, :login_not_allowed, message} ->
          Logger.warning("Login not allowed: #{message}")

          conn
          |> redirect(:noop, %{
            status: "error",
            code: "login_not_allowed"
          })

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

  get "/destroyed_account" do
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

  defp find_user(user_data) do
    case Guard.OIDC.User.find_user_by_oidc_id(user_data[:oidc_user_id]) do
      {:ok, user} ->
        Logger.debug(
          "Found user with oidc_user_id: #{inspect(user_data[:oidc_user_id])}: #{inspect(user)}"
        )

        case Guard.Store.User.Front.find(user.id) do
          {:ok, front_user = %Guard.FrontRepo.User{blocked_at: nil}} ->
            Logger.debug(
              "Found front user with oidc_user_id: #{inspect(user_data[:oidc_user_id])}: #{inspect(front_user)}"
            )

            {:ok, front_user}

          {:ok, _} ->
            {:error, :user_blocked}

          {:error, :not_found} ->
            {:error, :user_not_found}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  # Verifies if the user is allowed to login with OIDC when default login method is SAML
  # Returns {:ok, boolean, error_message}
  defp verify_oidc_login_allowed(user_data) do
    Logger.debug("Verifying if OIDC login is allowed for user_data: #{inspect(user_data)}")

    # If default login method is not SAML, always allow OIDC login
    if default_login_method() != "saml" do
      {:ok, true, nil}
    else
      verify_oidc_login_allowed_on_saml(user_data)
    end
  end

  defp verify_oidc_login_allowed_on_saml(user_data) do
    Logger.debug("Verifying if OIDC login is allowed for user_data: #{inspect(user_data)}")

    case find_user(user_data) do
      {:ok, user} ->
        Logger.debug(
          "Found user with oidc_user_id: #{inspect(user_data[:oidc_user_id])}: #{inspect(user)}"
        )

        verify_oidc_user_login_allowed_on_saml(user)

      {:error, error} ->
        Logger.error(
          "Error finding user with user_data: #{inspect(user_data)} error: #{inspect(error)}"
        )

        {:ok, false,
         "Login is not allowed when using SAML as the default authentication method. Please contact your administrator."}
    end
  end

  defp verify_oidc_user_login_allowed_on_saml(user) do
    if user != nil and user.creation_source == nil && !user.single_org_user do
      {:ok, true, nil}
    else
      Logger.warning("OIDC login not allowed for this user")

      {:ok, false,
       "Login is not allowed when using SAML as the default authentication method. Please contact your administrator."}
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
    user_agent =
      case get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        _ -> ""
      end

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
         conn.request_path =~ "auth" or conn.request_path =~ "cli" or
         conn.request_path =~ "device" do
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
