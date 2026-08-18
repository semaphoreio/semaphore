defmodule Notifications.Egress.UrlGuard do
  @moduledoc """
  Application-layer egress guard for outbound notification requests
  (webhooks and Slack). Called synchronously before every HTTPoison
  request against a customer-configured URL.

  Three fail-closed stages:

    1. Syntactic validation: require an http/https scheme and a non-empty
       host, reject non-UTF-8 input, and reject any literal control byte
       (CR/LF/NUL) in the URL or in the percent-decoded host. This blocks
       request-line and header injection at the app layer regardless of the
       HTTP client version.

    2. DNS-resolve + IP egress filter: resolve the host (percent-decoded and
       normalized here, so the guard sees the true target) across both IPv4
       and IPv6, then classify every resolved address. If ANY resolved IP is
       loopback, link-local, private (RFC1918/ULA/CGNAT), reserved, or a
       cloud metadata address, the whole request is rejected. Resolution
       failure or timeout fails closed.

    3. Connection pinning: from the resolved-and-vetted set the guard picks a
       single public IP and returns it in a `Notifications.Egress.Target`.
       Callers connect to THAT IP, not the hostname, so the address that was
       vetted is the address that is dialed. For https the returned
       `ssl_options` keep TLS SNI and certificate hostname verification bound
       to the ORIGINAL hostname (verify_peer against the trusted CA bundle),
       so legitimate customer endpoints keep working while the pinned IP
       closes the DNS-rebinding / TOCTOU window: the attacker cannot answer a
       public IP to the guard and an internal one to the HTTP client, because
       the client never re-resolves.

  This is defense-in-depth, not a substitute for a network-layer egress
  policy or a patched HTTP client.
  """

  import Bitwise

  require Logger

  alias Notifications.Egress.Target

  @schemes ~w(http https)

  # Bound each DNS lookup; a hung resolver must not stall the worker. A lookup
  # that exceeds this is treated as unresolvable (fail-closed).
  @resolve_timeout_ms 2_000

  @type reason ::
          :bad_url
          | :bad_scheme
          | :missing_host
          | :control_char
          | :unresolvable
          | {:blocked_ip, :inet.ip_address()}

  @doc """
  Verify that `url` is safe to request. Returns `{:ok, %Target{}}` for a
  syntactically valid http(s) URL whose host resolves exclusively to public
  IP addresses (the target carries the pinned IP and connection options), and
  `{:error, reason}` otherwise.
  """
  @spec verify(term()) :: {:ok, Target.t()} | {:error, reason()}
  def verify(url) when is_binary(url) do
    with :ok <- no_control_chars(url),
         %URI{scheme: scheme, host: host} = uri <- URI.parse(url),
         :ok <- validate_scheme(scheme),
         {:ok, host} <- validate_host(host),
         {:ok, ips} <- resolve(host),
         :ok <- check_ips(ips) do
      {:ok, build_target(uri, host, pick_ip(ips))}
    end
  end

  def verify(_), do: {:error, :bad_url}

  # --- Stage 1: syntactic validation ---------------------------------------

  # Operate on raw bytes and gate on UTF-8 validity so malformed input is a
  # clean {:error, ...} the caller can meter and log, never a raised
  # UnicodeConversionError that skips the blocked metric.
  defp no_control_chars(string) do
    cond do
      not String.valid?(string) -> {:error, :bad_url}
      has_control_byte?(string) -> {:error, :control_char}
      true -> :ok
    end
  end

  defp has_control_byte?(<<byte, _rest::binary>>) when byte <= 0x1F or byte == 0x7F, do: true
  defp has_control_byte?(<<_byte, rest::binary>>), do: has_control_byte?(rest)
  defp has_control_byte?(<<>>), do: false

  defp validate_scheme(scheme) when scheme in @schemes, do: :ok
  defp validate_scheme(_), do: {:error, :bad_scheme}

  defp validate_host(host) when is_binary(host) and host != "" do
    decoded = URI.decode(host)

    cond do
      decoded == "" -> {:error, :missing_host}
      not String.valid?(decoded) -> {:error, :bad_url}
      has_control_byte?(decoded) -> {:error, :control_char}
      true -> {:ok, decoded}
    end
  end

  defp validate_host(_), do: {:error, :missing_host}

  # --- Stage 2: resolution + IP egress filter ------------------------------

  defp resolve(host) do
    {mod, fun} =
      Application.get_env(:notifications, :egress_resolver, {__MODULE__, :default_resolve})

    case apply(mod, fun, [host]) do
      {:ok, []} -> {:error, :unresolvable}
      {:ok, ips} -> {:ok, ips}
      {:error, _} -> {:error, :unresolvable}
      _ -> {:error, :unresolvable}
    end
  end

  @doc false
  # Default resolver: IP literals are parsed directly (no DNS); host names are
  # resolved across both address families under a bounded timeout. A lookup
  # timeout fails closed (`{:error, :timeout}` -> `:unresolvable`). Returns
  # `{:ok, [ip]}` or `{:error, reason}`.
  def default_resolve(host) do
    charlist = String.to_charlist(host)

    case :inet.parse_address(charlist) do
      {:ok, ip} ->
        {:ok, [ip]}

      {:error, _} ->
        with {:ok, v4} <- getaddrs(charlist, :inet),
             {:ok, v6} <- getaddrs(charlist, :inet6) do
          case v4 ++ v6 do
            [] -> {:error, :nxdomain}
            ips -> {:ok, ips}
          end
        end
    end
  end

  defp getaddrs(charlist, family) do
    task = Task.async(fn -> :inet.getaddrs(charlist, family) end)

    case Task.yield(task, @resolve_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, addrs}} -> {:ok, addrs}
      # No records for this family (e.g. nxdomain / no AAAA) is not fatal on
      # its own; the other family may still answer.
      {:ok, {:error, _}} -> {:ok, []}
      # Timed out or the lookup process died: fail closed.
      _ -> {:error, :timeout}
    end
  end

  defp check_ips(ips) do
    case Enum.find(ips, &blocked?/1) do
      nil -> :ok
      ip -> {:error, {:blocked_ip, ip}}
    end
  end

  # All ips are public here (check_ips passed); pin the first as the dial
  # target. resolve/1 guarantees the list is non-empty.
  defp pick_ip([ip | _]), do: ip

  # --- Stage 3: connection pinning -----------------------------------------

  defp build_target(%URI{scheme: scheme, port: port} = uri, host, ip) do
    %Target{
      ip: ip,
      url: build_request_url(scheme, ip_literal(ip), port, uri.path, uri.query),
      host_header: build_host_header(scheme, host, port),
      ssl_options: ssl_options(scheme, host)
    }
  end

  defp build_request_url(scheme, ip_host, port, path, query) do
    port_part = if port, do: ":#{port}", else: ""
    path_part = path || "/"
    query_part = if query, do: "?#{query}", else: ""
    "#{scheme}://#{ip_host}#{port_part}#{path_part}#{query_part}"
  end

  # Preserve the original host (and non-default port) for the Host header so
  # the destination still routes/vhosts as the customer configured.
  defp build_host_header(scheme, host, port) do
    header_host = bracket_if_v6(host)

    if port in [nil, default_port(scheme)] do
      header_host
    else
      "#{header_host}:#{port}"
    end
  end

  # For https, pin SNI and certificate hostname verification to the ORIGINAL
  # hostname while the socket connects to the vetted IP. verify_peer and the
  # trusted CA bundle come from hackney's secure defaults (merged in); we only
  # override SNI and the hostname-check binding. The verify_fun (hackney's own
  # hostname verifier) is rebound to the original host because it, not
  # customize_hostname_check, performs the actual match when a custom
  # verify_fun is installed. customize_hostname_check is kept for parity with
  # the default secure path.
  defp ssl_options("https", host) do
    hostname = String.to_charlist(host)

    [
      verify: :verify_peer,
      server_name_indication: hostname,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)],
      verify_fun: {&:ssl_verify_hostname.verify_fun/3, [check_hostname: hostname]}
    ]
  end

  defp ssl_options(_scheme, _host), do: []

  defp ip_literal({_, _, _, _} = ip), do: ip |> :inet.ntoa() |> to_string()

  defp ip_literal({_, _, _, _, _, _, _, _} = ip),
    do: "[" <> (ip |> :inet.ntoa() |> to_string()) <> "]"

  defp bracket_if_v6(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, {_, _, _, _, _, _, _, _}} -> "[" <> host <> "]"
      _ -> host
    end
  end

  defp default_port("https"), do: 443
  defp default_port("http"), do: 80
  defp default_port(_), do: nil

  @doc """
  True if `ip` is a non-public destination (loopback, link-local, private,
  reserved, or cloud metadata), including IPv4 addresses embedded in IPv6.
  """
  @spec blocked?(:inet.ip_address()) :: boolean()
  def blocked?({a, b, c, d}), do: blocked_v4?(a, b, c, d)

  def blocked?({a, b, c, d, e, f, g, h}) do
    cond do
      # unspecified :: and loopback ::1
      {a, b, c, d, e, f, g, h} == {0, 0, 0, 0, 0, 0, 0, 0} -> true
      {a, b, c, d, e, f, g, h} == {0, 0, 0, 0, 0, 0, 0, 1} -> true
      # fe80::/10 link-local
      (a &&& 0xFFC0) == 0xFE80 -> true
      # fc00::/7 unique-local (covers fd00:ec2::254 AWS IMDS v6)
      (a &&& 0xFE00) == 0xFC00 -> true
      # 2001:db8::/32 documentation
      a == 0x2001 and b == 0x0DB8 -> true
      # Embedded IPv4 forms: unwrap and re-run the v4 classifier.
      embedded_v4(a, b, c, d, e, f, g, h) != nil -> blocked_embedded(a, b, c, d, e, f, g, h)
      true -> false
    end
  end

  def blocked?(_), do: true

  defp blocked_embedded(a, b, c, d, e, f, g, h) do
    case embedded_v4(a, b, c, d, e, f, g, h) do
      {w1, w2, w3, w4} -> blocked_v4?(w1, w2, w3, w4)
      _ -> false
    end
  end

  # Returns the embedded IPv4 tuple for IPv4-in-IPv6 forms, else nil.
  defp embedded_v4(a, b, c, d, e, f, g, h) do
    cond do
      # ::ffff:0:0/96 IPv4-mapped
      a == 0 and b == 0 and c == 0 and d == 0 and e == 0 and f == 0xFFFF ->
        words_to_v4(g, h)

      # ::/96 IPv4-compatible (deprecated), excluding :: and ::1
      a == 0 and b == 0 and c == 0 and d == 0 and e == 0 and f == 0 and
          not (g == 0 and (h == 0 or h == 1)) ->
        words_to_v4(g, h)

      # 64:ff9b::/96 NAT64
      a == 0x0064 and b == 0xFF9B and c == 0 and d == 0 and e == 0 and f == 0 ->
        words_to_v4(g, h)

      # 2002::/16 6to4 (embedded v4 in words 2-3)
      a == 0x2002 ->
        words_to_v4(b, c)

      # 2001::/32 Teredo (server v4 in words 3-4)
      a == 0x2001 and b == 0x0000 ->
        words_to_v4(c, d)

      true ->
        nil
    end
  end

  defp words_to_v4(hi, lo) do
    {hi >>> 8 &&& 0xFF, hi &&& 0xFF, lo >>> 8 &&& 0xFF, lo &&& 0xFF}
  end

  # --- IPv4 classifier -----------------------------------------------------

  defp blocked_v4?(a, b, c, d) do
    cond do
      a == 0 -> true
      a == 10 -> true
      a == 100 and b >= 64 and b <= 127 -> true
      a == 127 -> true
      a == 169 and b == 254 -> true
      a == 172 and b >= 16 and b <= 31 -> true
      a == 192 and b == 0 and c == 0 -> true
      a == 192 and b == 0 and c == 2 -> true
      a == 192 and b == 168 -> true
      a == 198 and (b == 18 or b == 19) -> true
      a == 198 and b == 51 and c == 100 -> true
      a == 203 and b == 0 and c == 113 -> true
      a >= 224 and a <= 239 -> true
      a >= 240 and a <= 255 -> true
      {a, b, c, d} == {255, 255, 255, 255} -> true
      true -> false
    end
  end
end
