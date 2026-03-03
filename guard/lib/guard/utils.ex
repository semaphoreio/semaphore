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
  def handle_ok_token_response(repo_host_account, body) do
    body =
      if is_binary(body) do
        Jason.decode!(body)
      else
        body
      end

    token = body["access_token"]
    expires_in = body["expires_in"]
    refresh_token = body["refresh_token"]

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
