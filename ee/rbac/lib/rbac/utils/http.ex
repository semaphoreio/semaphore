defmodule Rbac.Utils.Http do
  require Logger

  @redirect_cookie_key "semaphore_redirect_to"
  @state_cookie_options [
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
      "" ->
        conn

      url ->
        conn |> put_state_value(@redirect_cookie_key, url)
    end
  end

  def fetch_redirect_value(conn, default) do
    Logger.info("FETCH REDIRECT VALUE")

    # First try only regular cookies
    conn_with_regular =
      try do
        regular_conn = Plug.Conn.fetch_cookies(conn)
        Logger.info("Regular cookies fetched successfully")
        regular_conn
      rescue
        e ->
          Logger.error("Error fetching regular cookies: #{inspect(e)}")
          conn
      end

    # Then try signed cookies
    conn_with_signed =
      try do
        signed_conn = Plug.Conn.fetch_cookies(conn_with_regular, :signed)
        Logger.info("Signed cookies fetched successfully")
        signed_conn
      rescue
        e ->
          Logger.error("Error fetching signed cookies: #{inspect(e)}")
          conn_with_regular
      end

    # Finally try encrypted cookies
    conn_with_all =
      try do
        encrypted_conn = Plug.Conn.fetch_cookies(conn_with_signed, :encrypted)
        Logger.info("Encrypted cookies fetched successfully")
        encrypted_conn
      rescue
        e ->
          Logger.error("Error fetching encrypted cookies: #{inspect(e)}")
          conn_with_signed
      end

    Logger.info("TEST1 #{inspect(conn_with_all)}")

    all_cookies =
      Map.merge(
        conn_with_all.cookies || %{},
        Map.merge(
          conn_with_all.signed_cookies || %{},
          conn_with_all.encrypted_cookies || %{}
        )
      )

    Logger.info("All cookies (regular, signed, encrypted): #{inspect(Map.keys(all_cookies))}")

    # Continue with original functionality
    case conn_with_all |> fetch_state_value(@redirect_cookie_key) do
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
    opts = @state_cookie_options ++ [domain: "." <> domain()]
    Logger.info("OPTS: #{inspect(opts)}")
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

  defp domain, do: Application.get_env(:rbac, :base_domain)
end
