defmodule Guard.Utils do
  require Logger

  def nil_uuid, do: "00000000-0000-0000-0000-000000000000"

  def valid_uuid?(uuid) do
    Ecto.UUID.dump!(uuid)
    true
  rescue
    _ -> false
  end

  def grpc_error!(type, message \\ "") when is_atom(type),
    do: raise(GRPC.RPCError, message: message, status: apply(GRPC.Status, type, []))

  def validate_uuid!(values) when is_list(values), do: Enum.each(values, &validate_uuid!(&1))

  def validate_uuid!(value) do
    if !valid_uuid?(value) do
      Logger.error("Invalid uuid #{inspect(value)}")

      grpc_error!(
        :invalid_argument,
        "Invalid uuid passed as an argument where uuid v4 was expected."
      )
    end
  end

  def non_empty_value_or_default(map, key, default) do
    case Map.get(map, key) do
      val when is_integer(val) and val > 0 -> {:ok, val}
      val when is_binary(val) and val != "" -> {:ok, val}
      val when is_list(val) and length(val) > 0 -> {:ok, val}
      _ -> {:ok, default}
    end
  end

  def timestamp_to_datetime(%{nanos: nanos, seconds: seconds}, _default)
      when nanos > 0 or seconds > 0 do
    (seconds * 1_000_000 + Integer.floor_div(nanos, 1_000))
    |> DateTime.from_unix(:microsecond)
  end

  def timestamp_to_datetime(_, default), do: {:ok, default}
end

defmodule Guard.Utils.OAuth do
  require Logger

  def handle_ok_token_response(repo_host_account, body) do
    body =
      if is_binary(body) do
        Jason.decode!(body)
      else
        body
      end

    token = body["access_token"]
    expires_in = body["expires_in"]
    # Some providers (e.g. GitHub) omit refresh_token on a 2xx response when
    # the existing refresh token is still valid (not rotated) - fall back to
    # the stored one instead of overwriting it with nil.
    refresh_token = body["refresh_token"] || repo_host_account.refresh_token

    expires_at = calc_expires_at(expires_in)

    # By default, GitHub don't expires, so the expires_at is nil
    nil_valid = repo_host_account.repo_host == "github"

    if valid_token?(expires_at, nil_valid: nil_valid) do
      update_token(repo_host_account, token, refresh_token, expires_at)
    end

    {:ok, {token, expires_at}}
  end

  defp update_token(repo_host_account, token, refresh_token, expires_at) do
    {:ok, parsed_expires_at} = expires_at |> DateTime.from_unix(:second)

    Guard.FrontRepo.RepoHostAccount.update_token(
      repo_host_account,
      token,
      refresh_token,
      parsed_expires_at
    )
  end

  def calc_expires_at(nil), do: nil

  def calc_expires_at(expires_in) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()
    current_time + expires_in
  end

  @doc """
  Validate token

  ## Options
    - nil_valid: In case expires_at is nil, set token is valid
  """
  def valid_token?(expires_at, opts \\ [])
  def valid_token?(nil, opts), do: opts[:nil_valid] == true

  def valid_token?(%DateTime{} = expires_at, _opts) do
    expires_at |> DateTime.to_unix() |> valid_token?()
  end

  def valid_token?(expires_at, _opts) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()
    # 5 minutes before expiration
    expires_at - 300 > current_time
  end

  @doc """
  Classify a provider OAuth token-refresh HTTP response into an action the
  caller should take:

    - `:ok`        - 2xx, the token can be used
    - `:revoked`   - genuine permanent revocation: the provider's body
                      signals `error=invalid_grant` (all providers) or
                      `error=bad_refresh_token` (GitHub)
    - `:transient` - everything else, INCLUDING a bare HTTP 401 /
                      `invalid_client` / `unauthorized_client`. Per RFC 6749
                      those mean OUR shared client_id/client_secret was
                      rejected, not a user's grant - treating a bare 401 as
                      a revoke would mass-revoke every account on that
                      provider. Also covers 403, 429, 5xx, or any other
                      4xx. The caller MUST NOT treat `:transient` as a
                      permanent revoke.
  """
  @spec classify_refresh_response(non_neg_integer(), term()) :: :ok | :revoked | :transient
  def classify_refresh_response(status, _body) when status in 200..299, do: :ok

  def classify_refresh_response(status, body) do
    cond do
      genuine_grant_revocation?(body) ->
        :revoked

      status == 401 ->
        Logger.warning(
          "Bitbucket/GitLab/GitHub OAuth client credentials rejected (HTTP 401) - " <>
            "config issue, not a user revoke"
        )

        :transient

      true ->
        :transient
    end
  end

  defp genuine_grant_revocation?(body) when is_map(body) do
    Map.get(body, "error") in ["invalid_grant", "bad_refresh_token"]
  end

  defp genuine_grant_revocation?(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> genuine_grant_revocation?(decoded)
      _ -> false
    end
  end

  defp genuine_grant_revocation?(_body), do: false

  # --- OAuth token/refresh HTTP client hardening (AtlassianEdge mitigation) ---

  # Default per-provider User-Agent for the token/refresh request. Hackney (the
  # HTTP adapter) otherwise sends a bare `hackney/x.y.z` UA, which edge/WAF
  # layers (e.g. AtlassianEdge) flag as a bad bot and answer with an empty-body
  # 403. A single env/app-env override lets us A/B the winning UA value against
  # a live edge without a redeploy (read at each call).
  @default_user_agents %{
    bitbucket: "Semaphore-Bitbucket-Integration/1.0",
    gitlab: "Semaphore-GitLab-Integration/1.0"
  }

  # Response headers logged per refresh attempt to fingerprint the edge/CDN/WAF
  # in front of the OAuth endpoint. Never includes the response body.
  @diagnostic_headers ~w(server via x-amz-cf-id cf-ray x-amzn-requestid x-amz-apigw-id)

  # Statuses an AtlassianEdge-style layer returns before the request ever
  # reaches OAuth. On these (with the edge fingerprint and no genuine
  # invalid_grant) the single-use refresh_token is NOT consumed, so retrying
  # with the same stored token is safe.
  @edge_retry_statuses [400, 401, 403, 500]

  @doc """
  Explicit User-Agent for the token/refresh HTTP client. A single app-env
  override (`:guard, :oauth_refresh_user_agent`, wired from
  `OAUTH_REFRESH_USER_AGENT`) beats the per-provider default so the value can
  be A/B-tested live.
  """
  def refresh_user_agent(provider) do
    case Application.get_env(:guard, :oauth_refresh_user_agent) do
      ua when is_binary(ua) and ua != "" -> ua
      _ -> Map.get(@default_user_agents, provider, "Semaphore-OAuth-Integration/1.0")
    end
  end

  @doc """
  Headers a real OAuth client sends, for `Tesla.Middleware.Headers` on the
  token/refresh client. Does not set Content-Type: that stays owned by the
  form/JSON middleware already on each client.
  """
  def token_client_headers(provider) do
    [
      {"user-agent", refresh_user_agent(provider)},
      {"accept", "application/json"}
    ]
  end

  @doc """
  Run a token/refresh POST with per-attempt observability and a bounded,
  jittered retry on AtlassianEdge-shaped failures.

  `request_fun` is a 0-arity closure that performs the POST and returns the
  raw `Tesla.post/3` result. It is called with the SAME body (same stored
  refresh_token) on every attempt: an edge-shaped failure never reached OAuth,
  so the single-use refresh_token was not rotated/consumed and reuse is safe.

  Returns the last `Tesla.post/3` result for the caller to classify. Genuine
  `invalid_grant`/`bad_refresh_token` and non-edge responses are returned on
  the first attempt (no wasteful retry).
  """
  def post_with_edge_retry(provider, rha_id, request_fun) when is_function(request_fun, 0) do
    run_refresh_attempt(provider, rha_id, request_fun, 1, max_refresh_attempts())
  end

  defp run_refresh_attempt(provider, rha_id, request_fun, attempt, max) do
    result = request_fun.()
    log_refresh_attempt(provider, rha_id, attempt, max, result)

    case result do
      {:ok, %Tesla.Env{status: status, body: body, headers: headers}} ->
        if attempt < max and edge_shaped_failure?(status, body, headers) do
          Logger.warning(
            "OAuth refresh got AtlassianEdge-shaped HTTP #{status} for " <>
              "provider=#{provider} rha=#{rha_id}; refresh_token preserved, " <>
              "retrying (#{attempt + 1}/#{max})"
          )

          backoff(attempt)
          run_refresh_attempt(provider, rha_id, request_fun, attempt + 1, max)
        else
          result
        end

      {:error, _reason} ->
        result
    end
  end

  @doc """
  An edge-shaped failure: a retry-eligible status carrying the AtlassianEdge
  fingerprint, with an EMPTY body and no genuine grant revocation - the actual
  bot-block signature (empty-body AtlassianEdge 403). A real Bitbucket backend
  error (e.g. a 500 with an error body) is NOT edge-shaped and is not retried.
  Public for tests.
  """
  def edge_shaped_failure?(status, body, headers) do
    status in @edge_retry_statuses and
      atlassian_edge?(headers) and
      empty_error_body?(body) and
      not genuine_grant_revocation?(body)
  end

  # The edge returns no body on a bot-block. Treat nil, an empty/whitespace
  # string, and an empty JSON object as "empty"; anything with actual content
  # (an error body from the OAuth app or the Bitbucket backend) is not.
  defp empty_error_body?(nil), do: true
  defp empty_error_body?(body) when is_binary(body), do: String.trim(body) in ["", "{}"]
  defp empty_error_body?(body) when is_map(body), do: map_size(body) == 0
  defp empty_error_body?(_), do: false

  # Per-attempt log line. Greppable prefix `OAuth refresh attempt`; exposes the
  # `server` header + HTTP status on every outcome (success and failure) so a
  # given UA can be observed moving us off AtlassianEdge. Never logs the body,
  # token, refresh_token, or client_secret.
  defp log_refresh_attempt(provider, rha_id, attempt, max, {:ok, %Tesla.Env{} = env}) do
    level = if env.status in 200..299, do: :info, else: :warning

    Logger.log(
      level,
      "OAuth refresh attempt provider=#{provider} rha=#{rha_id} " <>
        "attempt=#{attempt}/#{max} status=#{env.status} " <>
        "server=#{inspect(response_server(env.headers))} " <>
        "headers=#{inspect(curated_headers(env.headers))}"
    )
  end

  defp log_refresh_attempt(provider, rha_id, attempt, max, {:error, reason}) do
    Logger.warning(
      "OAuth refresh attempt provider=#{provider} rha=#{rha_id} " <>
        "attempt=#{attempt}/#{max} status=network_error error=#{inspect(reason)}"
    )
  end

  defp atlassian_edge?(headers) when is_list(headers) do
    headers
    |> response_server()
    |> case do
      server when is_binary(server) ->
        String.contains?(String.downcase(server), "atlassianedge")

      _ ->
        false
    end
  end

  defp atlassian_edge?(_), do: false

  defp response_server(headers) when is_list(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == "server", do: value
    end)
  end

  defp response_server(_), do: nil

  defp curated_headers(headers) when is_list(headers) do
    headers
    |> Enum.filter(fn {key, _value} -> String.downcase(to_string(key)) in @diagnostic_headers end)
    |> Enum.into(%{})
  end

  defp curated_headers(_), do: %{}

  defp backoff(attempt) do
    base = Application.get_env(:guard, :oauth_refresh_retry_base_ms, 200)
    jitter = Application.get_env(:guard, :oauth_refresh_retry_jitter_ms, 300)
    delay = base * attempt + if(jitter > 0, do: :rand.uniform(jitter), else: 0)
    if delay > 0, do: Process.sleep(delay)
  end

  defp max_refresh_attempts, do: Application.get_env(:guard, :oauth_refresh_max_attempts, 3)
end

defmodule Guard.Utils.Http do
  require Logger

  defmodule RequestLogger do
    import Plug.Conn

    def init(options), do: options

    def call(conn, _opts) do
      start = System.monotonic_time()

      register_before_send(conn, fn conn ->
        stop = System.monotonic_time()

        time_us = System.convert_time_unit(stop - start, :native, :microsecond)
        time_ms = div(time_us, 100) / 10

        Logger.info(fn ->
          "#{conn.method} #{conn.request_path} #{conn.status} #{time_ms}ms"
        end)

        conn
      end)
    end
  end

  @redirect_cookie_key "semaphore_redirect_to"
  @state_cookie_options [
    encrypt: true,
    max_age: 30 * 60,
    # If `same_site` is set to `Strict` then the cookie will not be sent on
    # IdP callback redirects, which will break the auth flow.
    same_site: "Lax",
    path: "/",
    secure: true,
    http_only: true
  ]

  def store_redirect_info(conn) do
    [
      conn.query_params["redirect_path"],
      conn.query_params["redirect_to"]
    ]
    |> Enum.filter(fn item -> item not in [nil, ""] end)
    |> List.last("")
    |> URI.decode()
    |> validate_url("")
    |> case do
      "" -> conn
      url -> store_redirect_info(conn, url)
    end
  end

  def store_redirect_info(conn, url), do: conn |> put_state_value(@redirect_cookie_key, url)

  def fetch_redirect_value(conn, default) do
    case conn |> fetch_state_value(@redirect_cookie_key) do
      {:ok, redirect_to, _conn} ->
        validate_url(redirect_to, default)

      _ ->
        default
    end
  end

  def clear_redirect_value(conn) do
    delete_state_value(conn, @redirect_cookie_key)
  end

  def put_state_value(conn, key, value) do
    Logger.debug("Putting state value into cookie for key: #{key}")

    value = :erlang.term_to_binary(value)

    opts =
      if key == @redirect_cookie_key do
        # If `same_site` is set to `Strict` then the cookie will not be sent on
        # IdP callback redirects, which will break the auth flow.
        Keyword.merge(@state_cookie_options,
          same_site: "None",
          domain: "." <> domain()
        )
      else
        @state_cookie_options
      end

    Plug.Conn.put_resp_cookie(conn, key, value, opts)
  end

  def delete_state_value(conn, key) do
    Logger.debug("Deleting state value from cookie for key: #{key}")

    Plug.Conn.delete_resp_cookie(conn, key, @state_cookie_options)
  end

  def redirect_to_url(conn, url, options \\ []) do
    query = options |> Keyword.get(:query, %{})

    url =
      url
      |> URI.parse()
      |> URI.append_query(URI.encode_query(query))
      |> URI.to_string()
      |> String.trim_trailing("?")
      |> String.trim_trailing("&")

    conn
    |> Plug.Conn.put_resp_header("location", url)
    |> Plug.Conn.send_resp(302, "")
  end

  def fetch_state_value(conn, key) do
    conn = Plug.Conn.fetch_cookies(conn, encrypted: [key])

    case Map.fetch(conn.cookies, key) do
      {:ok, encoded_state} ->
        {:ok, Plug.Crypto.non_executable_binary_to_term(encoded_state, [:safe]), conn}

      :error ->
        Logger.warn("State key: #{key} not found in cookies")
        {:error, "State key: #{key} not found in cookies"}
    end
  end

  @doc """
    Validates if the URL has the correct domain and returns the URL if it does. Otherwise, returns the default URL.

    ## Examples
      iex> validate_url(nil, "https://me.semaphore.com")
      "https://me.semaphore.com"
      iex> validate_url("https://localhost.example.com", "https://me.semaphore.com")
      "https://me.semaphore.com"
      iex> validate_url("https://example.com?query=localhost", "https://me.semaphore.com")
      "https://me.semaphore.com"
      iex> validate_url("https://xxxlocalhost", "https://me.semaphore.com")
      "https://me.semaphore.com"
      iex> validate_url("https://localhost", "https://me.semaphore.com")
      "https://localhost"
      iex> validate_url("https://something.localhost", "https://me.semaphore.com")
      "https://something.localhost"
  """
  @spec validate_url(String.t() | nil, String.t()) :: String.t()
  def validate_url(nil, default), do: default

  def validate_url(url, default) do
    url_scheme = URI.parse(url)

    domain_full_match? = (url_scheme.host || "") == domain()
    domain_partial_match? = String.ends_with?(url_scheme.host || "", ".#{domain()}")
    domain_matches? = domain_full_match? or domain_partial_match?

    if domain_matches? do
      url
    else
      default
    end
  end

  defp domain, do: Application.get_env(:guard, :base_domain)
end
