defmodule PipelinesAPI.Util.ClientMetrics do
  @moduledoc """
  Per-request metric describing which client issued the request, so sem-ai
  (CLI / MCP) traffic is distinguishable from generic API traffic in Grafana.

  The SaaS statsd_graphite backend keeps only the first 3 positional tags
  (`Watchman.Server` pads with `no_tag` and `Enum.take(3)`), so the request
  status is encoded in the metric *name* suffix rather than a tag — that leaves
  all three tag slots for the client dimensions:

      tags = [source, command, version]
      name = "PipelinesAPI.router.client_request.<status>"

  `source` is read from the `x-semaphore-client-*` headers sem-ai attaches and
  defaults to `"api"` for every other (header-less) caller. `command` and
  `version` are sanitised against a tight allow-list before they become tags so
  a malformed/spoofed header can't explode Graphite cardinality.
  """

  alias PipelinesAPI.Util.Metrics
  alias Plug.Conn

  @metric "PipelinesAPI.router.client_request"
  @na "na"
  @known_sources ~w(semai-cli semai-mcp)
  @command_regex ~r/\A[a-z0-9_]{1,50}\z/
  @version_regex ~r/\A[A-Za-z0-9._+-]{1,30}\z/

  @doc """
  Register a before_send hook that submits the timing + per-status counter.
  """
  def track_request(conn) do
    start = System.monotonic_time(:millisecond)
    tags = client_tags(conn)

    Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time(:millisecond) - start
      Watchman.submit({@metric, tags}, duration, :timing)
      Metrics.increment(metric_name(conn.status), tags)
      conn
    end)
  end

  @doc "Positional Watchman tags: [source, command, version]."
  def client_tags(conn),
    do: [source(conn), command(conn), version(conn)]

  @doc "Status-suffixed metric name, e.g. \"...client_request.ok\"."
  def metric_name(status), do: "#{@metric}.#{status_label(status)}"

  @doc "Header values rendered for the request log line."
  def log_fields(conn) do
    [src, cmd, ver] = client_tags(conn)
    [" - client=", src, " command=", cmd, " version=", ver]
  end

  def source(conn) do
    case header(conn, "x-semaphore-client-source") do
      src when src in @known_sources -> src
      _ -> "api"
    end
  end

  def status_label(status) when is_integer(status) and status >= 500, do: "server_error"
  def status_label(status) when is_integer(status) and status >= 400, do: "client_error"
  def status_label(status) when is_integer(status), do: "ok"
  def status_label(_status), do: "unknown"

  defp command(conn), do: sanitize(header(conn, "x-semaphore-client-command"), @command_regex)
  defp version(conn), do: sanitize(header(conn, "x-semaphore-client-version"), @version_regex)

  defp sanitize(value, regex) when is_binary(value) do
    if Regex.match?(regex, value), do: value, else: @na
  end

  defp sanitize(_value, _regex), do: @na

  defp header(conn, name) do
    conn
    |> Conn.get_req_header(name)
    |> List.first()
  end
end
