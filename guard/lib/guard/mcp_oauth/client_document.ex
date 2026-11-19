defmodule Guard.McpOAuth.ClientDocument do
  @moduledoc """
  Client ID Metadata Documents: a client whose client_id is an https URL
  serves its metadata there, and guard reads it at sign-in instead of
  registering the client. Only public clients: the document must say
  token_endpoint_auth_method "none".

  A document is fetched over https, without following redirects, within
  5 seconds and 5 KiB, from an address that is not private, loopback
  or link-local: the one guard resolved and connects to. It is cached as its
  Cache-Control says, from 5 minutes to a day.

  MCP_OAUTH_CIMD_LOCAL_HOSTS (comma-separated host:port) lists hosts that may
  serve documents over http and from private addresses, for local development
  and E2E. Production leaves it unset.
  """

  import Bitwise

  alias Guard.Repo.McpOAuthClient

  @cache :mcp_oauth_client_documents
  @timeout_ms 5_000
  @max_bytes 5_120
  @min_ttl_seconds 300
  @max_ttl_seconds 86_400

  # Unspecified, private, shared, loopback, link-local, benchmarking, multicast
  # and reserved.
  @private_ipv4 [
    {{0, 0, 0, 0}, 8},
    {{10, 0, 0, 0}, 8},
    {{100, 64, 0, 0}, 10},
    {{127, 0, 0, 0}, 8},
    {{169, 254, 0, 0}, 16},
    {{172, 16, 0, 0}, 12},
    {{192, 168, 0, 0}, 16},
    {{198, 18, 0, 0}, 15},
    {{224, 0, 0, 0}, 3}
  ]

  def cache, do: @cache

  @doc "Whether a client_id names a metadata document rather than a registered client."
  @spec document?(term()) :: boolean()
  def document?(client_id) when is_binary(client_id),
    do: String.starts_with?(client_id, ["https://", "http://"])

  def document?(_), do: false

  @doc """
  The client a document describes, or why it describes none: the reason
  completes "client_id's metadata document ...".
  """
  @spec fetch(String.t()) :: {:ok, McpOAuthClient.t()} | {:error, String.t()}
  def fetch(url) do
    case Cachex.get(@cache, url) do
      {:ok, %McpOAuthClient{} = client} ->
        {:ok, client}

      _ ->
        with {:ok, uri} <- parse(url),
             {:ok, address} <- resolve(uri),
             {:ok, body, ttl_seconds} <- get(uri, address),
             {:ok, client} <- client(body, url) do
          Cachex.put(@cache, url, client, ttl: :timer.seconds(ttl_seconds))
          {:ok, client}
        end
    end
  end

  defp parse(url) do
    uri = URI.parse(url)

    cond do
      uri.host in [nil, ""] or (uri.scheme == "http" and not local?(uri)) ->
        {:error, "is not at an https URL"}

      uri.path in [nil, "/"] ->
        {:error, "is not at a URL with a path"}

      uri.userinfo != nil or uri.fragment != nil ->
        {:error, "is at a URL with a user or a fragment"}

      Enum.any?(String.split(uri.path, "/"), &(&1 in [".", ".."])) ->
        {:error, "is at a URL with a . or .. segment"}

      true ->
        {:ok, uri}
    end
  end

  defp resolve(%URI{host: host} = uri) do
    name = String.to_charlist(host)

    addresses =
      case :inet.parse_address(name) do
        {:ok, address} -> [address]
        {:error, _} -> lookup(name)
      end

    case addresses do
      [] ->
        {:error, "is on a host that does not resolve"}

      [address | _] ->
        if private?(address) and not local?(uri),
          do: {:error, "is on a private address"},
          else: {:ok, address}
    end
  end

  defp lookup(name) do
    Enum.find_value([:inet, :inet6], [], fn family ->
      case :inet.getaddrs(name, family, @timeout_ms) do
        {:ok, [_ | _] = addresses} -> addresses
        _ -> nil
      end
    end)
  end

  defp private?({_, _, _, _} = address) do
    Enum.any?(@private_ipv4, fn {network, bits} ->
      ipv4(address) >>> (32 - bits) == ipv4(network) >>> (32 - bits)
    end)
  end

  defp private?({0, 0, 0, 0, 0, 0xFFFF, high, low}),
    do: private?({high >>> 8, high &&& 0xFF, low >>> 8, low &&& 0xFF})

  defp private?({0, 0, 0, 0, 0, 0, 0, last}) when last in [0, 1], do: true

  defp private?({first, _, _, _, _, _, _, _}) do
    (first &&& 0xFE00) == 0xFC00 or (first &&& 0xFFC0) == 0xFE80 or (first &&& 0xFF00) == 0xFF00
  end

  defp ipv4({a, b, c, d}), do: a <<< 24 ||| b <<< 16 ||| c <<< 8 ||| d

  defp local?(%URI{host: host, port: port}),
    do: "#{host}:#{port}" in local_hosts()

  defp local_hosts do
    (System.get_env("MCP_OAUTH_CIMD_LOCAL_HOSTS") || "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp get(uri, address) do
    scheme = if uri.scheme == "https", do: :https, else: :http
    path = if uri.query, do: "#{uri.path}?#{uri.query}", else: uri.path
    deadline = System.monotonic_time(:millisecond) + @timeout_ms

    options = [hostname: uri.host, mode: :passive, transport_opts: [timeout: @timeout_ms]]

    with {:ok, conn} <- Mint.HTTP1.connect(scheme, address, uri.port, options),
         {:ok, conn, ref} <-
           Mint.HTTP1.request(conn, "GET", path, [{"accept", "application/json"}], nil) do
      {conn, result} =
        read(conn, ref, deadline, %{status: nil, headers: [], body: "", done: false})

      Mint.HTTP1.close(conn)
      result
    else
      _ -> {:error, "could not be fetched"}
    end
  end

  defp read(conn, ref, deadline, response) do
    remaining = deadline - System.monotonic_time(:millisecond)

    case remaining > 0 && Mint.HTTP1.recv(conn, 0, remaining) do
      {:ok, conn, parts} ->
        response = Enum.reduce(parts, response, &collect(&1, &2, ref))

        cond do
          byte_size(response.body) > @max_bytes -> {conn, {:error, "is over #{@max_bytes} bytes"}}
          response.done -> {conn, answer(response)}
          true -> read(conn, ref, deadline, response)
        end

      {:error, conn, _reason, _parts} ->
        {conn, {:error, "could not be fetched"}}

      false ->
        {conn, {:error, "took over #{@timeout_ms}ms"}}
    end
  end

  defp collect({:status, ref, status}, response, ref), do: %{response | status: status}
  defp collect({:headers, ref, headers}, response, ref), do: %{response | headers: headers}
  defp collect({:data, ref, data}, response, ref), do: %{response | body: response.body <> data}
  defp collect({:done, ref}, response, ref), do: %{response | done: true}
  defp collect(_part, response, _ref), do: response

  defp answer(%{status: 200, headers: headers, body: body}), do: {:ok, body, ttl_seconds(headers)}
  defp answer(%{status: status}) when status in 300..399, do: {:error, "redirects"}
  defp answer(%{status: status}), do: {:error, "answered #{status}"}

  defp ttl_seconds(headers) do
    max_age =
      Enum.find_value(headers, fn
        {"cache-control", value} ->
          case Regex.run(~r/(?:^|,)\s*max-age=(\d+)/i, value) do
            [_, seconds] -> String.to_integer(seconds)
            nil -> nil
          end

        _ ->
          nil
      end)

    (max_age || @min_ttl_seconds) |> max(@min_ttl_seconds) |> min(@max_ttl_seconds)
  end

  defp client(body, url) do
    with {:ok, %{} = document} <- Jason.decode(body),
         :ok <- validate(document, url) do
      name = document["client_name"]

      {:ok,
       %McpOAuthClient{
         client_id: url,
         client_name: if(is_binary(name) and name != "", do: name),
         redirect_uris: document["redirect_uris"]
       }}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      _ -> {:error, "is not a JSON object"}
    end
  end

  defp validate(document, url) do
    cond do
      document["client_id"] != url ->
        {:error, "names another client_id"}

      document["token_endpoint_auth_method"] != "none" ->
        {:error, "is not for a public client: token_endpoint_auth_method must be none"}

      not redirect_uris?(document["redirect_uris"]) ->
        {:error, "lists no redirect_uris"}

      true ->
        :ok
    end
  end

  defp redirect_uris?([_ | _] = uris), do: Enum.all?(uris, &is_binary/1)
  defp redirect_uris?(_), do: false
end
