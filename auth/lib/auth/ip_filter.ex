defmodule Auth.IpFilter do
  require Logger

  def block?(client_ip, org) do
    if Enum.empty?(org.ip_allow_list) do
      false
    else
      _block?(client_ip, org.ip_allow_list)
    end
  end

  defp _block?(nil, _) do
    Watchman.increment("auth.ip_filter.empty_ip")
    log_error("Empty IP")

    true
  end

  defp _block?(client_ip, ip_allow_list) do
    !Enum.any?(ip_allow_list, fn i -> allow?(i, client_ip) end)
  end

  defp allow?(cidr_or_ip, client_ip) do
    if cidr?(cidr_or_ip) do
      InetCidr.parse(cidr_or_ip, true) |> InetCidr.contains?(client_ip)
    else
      InetCidr.parse_address!(cidr_or_ip) == client_ip
    end
  rescue
    e ->
      Watchman.increment("auth.ip_filter.error")
      log_error("Error parsing '#{inspect(cidr_or_ip)}': #{inspect(e)}")

      # If something goes wrong here, it means the validation for an organization
      # IPs/CIDRs is not working properly, which is very unlikely, so we fail open
      false
  end

  defp cidr?(cidr_or_ip) do
    String.contains?(cidr_or_ip, "/")
  end

  defp log_error(message) do
    Logger.error("[IpFilter] #{message}")
  end
end
