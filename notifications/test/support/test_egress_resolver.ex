defmodule Support.TestEgressResolver do
  @moduledoc """
  Deterministic, offline resolver used by `Notifications.Egress.UrlGuard` in the
  test environment. IP literals are parsed directly; known test host names map to
  fixed addresses so egress-guard behaviour is exercised without touching the
  network. Unknown host names fail closed (`:nxdomain`).
  """

  @hosts %{
    # Public destinations - allowed.
    "hooks.slack.com" => [{3, 5, 5, 5}],
    "public.example.test" => [{93, 184, 216, 34}],
    "public6.example.test" => [{0x2606, 0x2800, 0x220, 0x1, 0x248, 0x1893, 0x25C8, 0x1946}],
    # Private / metadata destinations - blocked.
    "private.internal.test" => [{10, 0, 0, 5}],
    "rfc1918-172.internal.test" => [{172, 16, 5, 5}],
    "rfc1918-192.internal.test" => [{192, 168, 1, 1}],
    "metadata.internal.test" => [{169, 254, 169, 254}],
    "loopback.internal.test" => [{127, 0, 0, 1}],
    # Public A-record plus a private one - must be rejected as a whole.
    "mixed.evil.test" => [{93, 184, 216, 34}, {10, 0, 0, 5}]
  }

  def resolve(host) do
    charlist = String.to_charlist(host)

    case :inet.parse_address(charlist) do
      {:ok, ip} ->
        {:ok, [ip]}

      {:error, _} ->
        case Map.fetch(@hosts, host) do
          {:ok, ips} -> {:ok, ips}
          :error -> {:error, :nxdomain}
        end
    end
  end
end
