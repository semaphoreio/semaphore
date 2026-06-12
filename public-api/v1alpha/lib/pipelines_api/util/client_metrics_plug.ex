defmodule PipelinesAPI.Plug.ClientMetrics do
  @moduledoc """
  Global router plug registering the per-request client-attribution hook
  (Watchman metrics + structured JSON log event) — see
  `PipelinesAPI.Util.ClientMetrics` for what gets emitted. Reads the
  `x-client-*` headers sem-ai attaches; header-less callers are attributed as
  source=api, so the hook covers all traffic.

  Health-check / ingress-probe paths are skipped so kubelet probes don't
  inflate the source=api counters or the log volume.
  """

  @behaviour Plug

  alias PipelinesAPI.Util.ClientMetrics
  alias Plug.Conn

  # Ingress / kubelet probe paths — no attribution.
  @skip_paths ~w(/health_check/ping /)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Conn{request_path: path} = conn, _opts) when path in @skip_paths, do: conn
  def call(conn, _opts), do: ClientMetrics.track_request(conn)
end
