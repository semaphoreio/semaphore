defmodule Audit.NetworkUtils do
  @type ip :: {byte(), byte(), byte(), byte()}

  @private_cidrs [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "127.0.0.0/8",
    "169.254.0.0/16",
    "100.64.0.0/10",
    "198.18.0.0/15",
    "192.0.0.0/24",
    "192.0.2.0/24",
    "192.88.99.0/24",
    "198.51.100.0/24",
    "203.0.113.0/24",
    "240.0.0.0/4",
    "255.255.255.255/32"
  ]

  @doc """
  Checks if the given URL or IP belongs to internal network.
  To fetch IP address from the URL, the URL hostname A Record is resolved.

  ## Examples

      iex> internal_url?("http://localhost")
      true

      iex> internal_url?("http://example.com")
      false

      iex> internal_url?("http://semaphoreci.com")
      false

      iex> internal_url?("google.com")
      false

      iex> internal_url?("127.0.0.1")
      true

      iex> internal_url?("127.0.0.1")
      true

      iex> internal_url?("172.16.0.1")
      true

      iex> internal_url?("192.168.0.1")
      true

      iex> internal_url?("8.8.8.8")
      false

      iex> internal_url?("255.255.255.255")
      true

      iex> internal_url?("192.0.2.1")
      true

      iex> internal_url?("89.0.2.1")
      false
  """
  @spec internal_url?(String.t()) :: boolean

  if Application.fetch_env!(:audit, :environment) == :test do
    # Special case for testing environment
    def internal_url?("S3") do
      false
    end

    def internal_url?("localhost") do
      false
    end
  end

  def internal_url?(url) do
    get_hostname(url)
    |> get_host_ips()
    |> Enum.any?(&private_ip?/1)
  end

  @spec private_ip?(ip) :: boolean
  defp private_ip?(ip) do
    @private_cidrs
    |> Enum.any?(fn cidr ->
      cidr = InetCidr.parse_cidr!(cidr)
      InetCidr.contains?(cidr, ip)
    end)
  end

  @spec get_hostname(String.t()) :: String.t()
  defp get_hostname(url) do
    uri = URI.parse(url)

    if uri.host == nil do
      url
    else
      uri.host
    end
  end

  @spec get_host_ips(String.t()) :: [ip]
  defp get_host_ips(hostname) do
    hostname
    |> InetCidr.parse_address()
    |> case do
      {:ok, ip} ->
        [ip]

      {:error, _} ->
        :inet.getaddr(String.to_charlist(hostname), :inet)
        |> case do
          {:ok, ip} ->
            [ip]

          _ ->
            []
        end
    end
  end
end
