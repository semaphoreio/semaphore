defmodule PipelinesAPI.Plug.ClientMetrics do
  @moduledoc """
  Global router plug that records a per-client request metric for every v1alpha
  endpoint served by this app. Reads the `x-semaphore-client-*` headers sem-ai
  attaches and submits via `PipelinesAPI.Util.ClientMetrics`. Header-less callers
  are tagged `source=api`, so the metric covers all traffic, not only sem-ai.
  """

  @behaviour Plug

  alias PipelinesAPI.Util.ClientMetrics

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts), do: ClientMetrics.track_request(conn)
end
