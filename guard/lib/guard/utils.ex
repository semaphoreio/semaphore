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
    # The refresh response body must degrade to :transient - never raise - on
    # anything we cannot parse into a token. github's OAuth token endpoint
    # answers `application/x-www-form-urlencoded` by default (we send no
    # `Accept: application/json`), so its 2xx body arrives as a raw form-encoded
    # STRING, not JSON; bitbucket/gitlab answer JSON. Decode by provider and
    # never raise: an empty / HTML / otherwise unexpected body degrades to
    # :transient. An unrescued raise would cross the gRPC boundary as INTERNAL
    # and escape before the negative cache is written, re-hammering the shared
    # OAuth credential every request.
    case decode_token_body(repo_host_account.repo_host, body) do
      {:ok, decoded} ->
        token = presence(decoded["access_token"])
        expires_in = normalize_expires_in(decoded["expires_in"])
        # Single-use rotation: capture the NEW refresh_token when the provider
        # returned one. Do NOT fall back to the stored/in-memory value - a 2xx
        # that omits refresh_token (GitHub, or an unchanged token) must leave
        # the stored column UNTOUCHED, never rewrite a possibly-stale snapshot
        # over a newer token a concurrent worker just rotated in.
        rotated_refresh_token = presence(decoded["refresh_token"])

        expires_at = resolve_expires_at(repo_host_account, expires_in)

        persist_refreshed_token(repo_host_account, token, rotated_refresh_token, expires_at)

      :error ->
        Logger.warning(
          "2xx token refresh response body was not decodable for " <>
            "rha=#{repo_host_account.id} user=#{repo_host_account.user_id} " <>
            "#{repo_host_account.repo_host}; treating as transient"
        )

        {:error, :transient}
    end
  end

  # Already-decoded map (e.g. gitlab, whose refresh client has JSON middleware).
  defp decode_token_body(_provider, body) when is_map(body), do: {:ok, body}

  # github answers form-urlencoded by default; still tolerate a JSON body.
  defp decode_token_body("github", body) when is_binary(body), do: decode_form_or_json(body)

  # bitbucket's refresh client carries no JSON middleware, so its JSON body
  # arrives as a raw string.
  defp decode_token_body(_provider, body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _ -> :error
    end
  end

  defp decode_token_body(_provider, _body), do: :error

  defp decode_form_or_json(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _ -> decode_form_urlencoded(body)
    end
  end

  defp decode_form_urlencoded(body) do
    case URI.decode_query(body) do
      decoded when map_size(decoded) > 0 -> {:ok, decoded}
      _ -> :error
    end
  rescue
    ArgumentError -> :error
  end

  # expires_in is an integer over JSON but a numeric string over
  # form-urlencoded (github). Normalise to a positive integer, else nil.
  defp normalize_expires_in(value) when is_integer(value) and value > 0, do: value

  defp normalize_expires_in(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} when int > 0 -> int
      _ -> nil
    end
  end

  defp normalize_expires_in(_value), do: nil

  # Fallback access-token lifetime when a 2xx omits expires_in. Kept well
  # under the providers' real access-token lifetime (Bitbucket/GitLab ~2h) so
  # we still refresh ahead of expiry, but long enough that we do not
  # re-refresh on every request.
  @default_access_token_ttl_seconds 3600

  # A 2xx with a usable expires_in: honor it (even a short one is a real
  # provider value).
  defp resolve_expires_at(_repo_host_account, expires_in)
       when is_integer(expires_in) and expires_in > 0,
       do: calc_expires_at(expires_in)

  # GitHub access tokens do not expire by default - leave token_expires_at nil.
  defp resolve_expires_at(%{repo_host: "github"}, _expires_in), do: nil

  # Any other provider with a missing/short expires_in on a 2xx: write a
  # conservative TTL instead of dropping the field, which would leave the old
  # (expired) timestamp and force a refresh on every request - churn against
  # a single-use rotation endpoint.
  defp resolve_expires_at(_repo_host_account, _expires_in),
    do: calc_expires_at(@default_access_token_ttl_seconds)

  # A 2xx with no usable access_token is a malformed/dropped rotation
  # response (a known failure mode of single-use rotation). Do NOT write it
  # back (it would either no-op or clobber a good token) and do NOT hand a
  # nil token to the caller - treat it as transient so the caller retries.
  defp persist_refreshed_token(repo_host_account, nil, _refresh_token, _expires_at) do
    Logger.warning(
      "2xx token refresh response missing access_token for rha=#{repo_host_account.id} " <>
        "user=#{repo_host_account.user_id} #{repo_host_account.repo_host}; treating as transient"
    )

    {:error, :transient}
  end

  # Persist on ANY 2xx that carries a token, regardless of how long the access
  # token is valid for: skipping the write on a short/missing expires_in would
  # silently drop the rotated refresh_token and guarantee a reuse burn on the
  # next refresh. The concurrency-safe persistence (optimistic lock, and - the
  # #1 fix - re-applying our rotation instead of discarding it when only an
  # UNRELATED column write lost us the lock) lives in the schema module.
  defp persist_refreshed_token(repo_host_account, token, rotated_refresh_token, expires_at) do
    Guard.FrontRepo.RepoHostAccount.persist_refreshed_token(
      repo_host_account,
      token,
      rotated_refresh_token,
      parse_expires_at(expires_at)
    )
  end

  defp parse_expires_at(nil), do: nil
  defp parse_expires_at(unix) when is_integer(unix), do: DateTime.from_unix!(unix, :second)

  defp presence(value) when value in [nil, ""], do: nil
  defp presence(value), do: value

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
