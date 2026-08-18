defmodule Notifications.Egress.UrlGuard do
  @moduledoc """
  Application-layer egress guard for outbound notification requests
  (webhooks and Slack). Called synchronously before every HTTPoison
  request against a customer-configured URL.

  Two fail-closed stages:

    1. Syntactic validation: require an http/https scheme and a non-empty
       host, and reject any literal control byte (CR/LF/NUL) in the URL or
       in the percent-decoded host. This blocks request-line and header
       injection at the app layer regardless of the HTTP client version.

    2. DNS-resolve + IP egress filter: resolve the host (percent-decoded and
       normalized here, so the guard sees the true target) across both IPv4
       and IPv6, then classify every resolved address. If ANY resolved IP is
       loopback, link-local, private (RFC1918/ULA/CGNAT), reserved, or a
       cloud metadata address, the whole request is rejected. Resolution
       failure fails closed. Every genuinely public destination is allowed,
       so legitimate customer endpoints keep working.

  This is defense-in-depth, not a substitute for a patched HTTP client.
  """

  import Bitwise

  require Logger

  @schemes ~w(http https)

  @type reason ::
          :bad_url
          | :bad_scheme
          | :missing_host
          | :control_char
          | :unresolvable
          | {:blocked_ip, :inet.ip_address()}

  @doc """
  Verify that `url` is safe to request. Returns `:ok` for a syntactically
  valid http(s) URL whose host resolves exclusively to public IP addresses,
  and `{:error, reason}` otherwise.
  """
  @spec verify(term()) :: :ok | {:error, reason()}
  def verify(url) when is_binary(url) do
    with :ok <- no_control_chars(url),
         %URI{scheme: scheme, host: host} <- URI.parse(url),
         :ok <- validate_scheme(scheme),
         {:ok, host} <- validate_host(host),
         {:ok, ips} <- resolve(host),
         :ok <- check_ips(ips) do
      :ok
    end
  end

  def verify(_), do: {:error, :bad_url}

  # --- Stage 1: syntactic validation ---------------------------------------

  defp no_control_chars(string) do
    if has_control_char?(string), do: {:error, :control_char}, else: :ok
  end

  defp has_control_char?(string) do
    String.to_charlist(string)
    |> Enum.any?(fn c -> c <= 0x1F or c == 0x7F end)
  end

  defp validate_scheme(scheme) when scheme in @schemes, do: :ok
  defp validate_scheme(_), do: {:error, :bad_scheme}

  defp validate_host(host) when is_binary(host) and host != "" do
    decoded = URI.decode(host)

    cond do
      decoded == "" -> {:error, :missing_host}
      has_control_char?(decoded) -> {:error, :control_char}
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
  # resolved across both address families. Returns `{:ok, [ip]}` or `{:error, reason}`.
  def default_resolve(host) do
    charlist = String.to_charlist(host)

    case :inet.parse_address(charlist) do
      {:ok, ip} ->
        {:ok, [ip]}

      {:error, _} ->
        v4 = getaddrs(charlist, :inet)
        v6 = getaddrs(charlist, :inet6)

        case v4 ++ v6 do
          [] -> {:error, :nxdomain}
          ips -> {:ok, ips}
        end
    end
  end

  defp getaddrs(charlist, family) do
    case :inet.getaddrs(charlist, family) do
      {:ok, addrs} -> addrs
      {:error, _} -> []
    end
  end

  defp check_ips(ips) do
    case Enum.find(ips, &blocked?/1) do
      nil -> :ok
      ip -> {:error, {:blocked_ip, ip}}
    end
  end

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
