defmodule Notifications.Egress.Target do
  @moduledoc """
  A vetted, connection-pinned egress target produced by
  `Notifications.Egress.UrlGuard.verify/1`.

  The guard resolves the customer host exactly once, classifies every
  resolved address, and captures a single vetted public IP here. Callers
  MUST connect using these fields (never the original hostname URL) so the
  IP that was vetted is the IP that is dialed. This closes the DNS-rebinding
  / TOCTOU window where the HTTP client would otherwise re-resolve the host
  at connect time and reach a different (internal) address.

  Fields:

    * `:ip` - the vetted public IP the request will be dialed against.
    * `:url` - the request URL with the host replaced by `:ip` (IPv6 is
      bracketed). Path, query and port are preserved from the original URL.
    * `:host_header` - the ORIGINAL host (with non-default port), to be sent
      as the `Host` header so the destination still routes/vhosts correctly.
    * `:ssl_options` - for https, `ssl:` options that pin TLS SNI and
      certificate hostname verification to the ORIGINAL hostname while
      connecting to `:ip`. Empty list for http.
  """

  @enforce_keys [:ip, :url, :host_header]
  defstruct [:ip, :url, :host_header, ssl_options: []]

  @type t :: %__MODULE__{
          ip: :inet.ip_address(),
          url: String.t(),
          host_header: String.t(),
          ssl_options: keyword()
        }
end
