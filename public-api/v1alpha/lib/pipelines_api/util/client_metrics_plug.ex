defmodule PipelinesAPI.Plug.ClientMetrics do
  @moduledoc """
  Global router plug that emits a structured JSON log event for every v1alpha
  request. Reads the `x-client-*` headers sem-ai attaches. Header-less callers
  are attributed as source=api, so the event covers all traffic.
  """

  @behaviour Plug

  alias PipelinesAPI.Util.ClientMetrics

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts), do: ClientMetrics.track_request(conn)
end
