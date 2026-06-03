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

  `source` is read from the `x-client-*` headers sem-ai attaches and
  defaults to `"api"` for every other (header-less) caller. `command` and
  `version` are sanitised against a tight allow-list before they become tags so
  a malformed/spoofed header can't explode Graphite cardinality.

  A second, deliberately generic counter — `api.client_usage`, tagged only by
  `[source]` — is emitted per request. Its service-agnostic name lets every API
  backend write the *same* measurement, so CLI-vs-MCP-vs-api usage aggregates
  across all endpoints (group by `source`); the per-service `service` tag (from
  each app's Watchman prefix) still gives the per-backend split when wanted.

  A third counter — `api.org_usage`, tagged `[org, source]` — counts per-request
  API volume per organization and client flavour. `org` comes from the auth-set
  `x-semaphore-org-*` headers (trusted, so cardinality stays bounded by real
  orgs). This is API-call *volume*, not deduped invocations — good enough to see
  which org leans on sem-ai and in what flavour.
  """

  alias PipelinesAPI.Util.Metrics
  alias Plug.Conn

  @metric "PipelinesAPI.router.client_request"
  @usage_metric "api.client_usage"
  @org_metric "api.org_usage"
  @na "na"
  @known_sources ~w(semai-cli semai-mcp)
  @command_regex ~r/\A[a-z0-9_-]{1,50}\z/
  @version_regex ~r/\A[A-Za-z0-9._+-]{1,30}\z/

  @doc """
  Register a before_send hook that submits the timing + per-status counter.
  """
  def track_request(conn) do
    start = System.monotonic_time(:millisecond)
    tags = client_tags(conn)
    [src | _] = tags

    Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time(:millisecond) - start
      Watchman.submit({@metric, tags}, duration, :timing)
      Metrics.increment(metric_name(conn.status), tags)
      Metrics.increment(@usage_metric, [src])
      track_org_usage(conn, src)
      conn
    end)
  end

  @doc """
  Positional Watchman tags: [source, command, version].

  Values are made graphite-safe — the carbon path separator `.` is replaced
  with `_` — so a dotted version like `1.4.0` doesn't split into extra path
  segments and corrupt the InfluxDB measurement name (it would otherwise shift
  every later position and weld the leftover fragments into the measurement).
  """
  def client_tags(conn),
    do: [source(conn), command(conn), version(conn)] |> Enum.map(&graphite_safe/1)

  @doc "Status-suffixed metric name, e.g. \"...client_request.ok\"."
  def metric_name(status), do: "#{@metric}.#{status_label(status)}"

  @doc "Generic, service-agnostic usage-counter name (identical across all backends)."
  def usage_metric, do: @usage_metric

  @doc "Single-tag list for the generic usage counter: [source]."
  def usage_tags(conn), do: [source(conn)]

  @doc "Per-org volume counter name."
  def org_usage_metric, do: @org_metric

  @doc """
  Org identity for the per-org volume counter, from the auth-set headers
  (`x-semaphore-org-username` preferred for readability, else `x-semaphore-org-id`).
  These are set by the auth service (trusted), not the client, so cardinality is
  bounded by real orgs. Returns nil when unauthenticated (no org present).
  """
  def org_tag(conn) do
    name = header(conn, "x-semaphore-org-username")
    id = header(conn, "x-semaphore-org-id")

    cond do
      is_binary(name) and name != "" -> graphite_safe(name)
      is_binary(id) and id != "" -> graphite_safe(id)
      true -> nil
    end
  end

  @doc "Header values rendered for the request log line."
  def log_fields(conn) do
    [
      " - client=",
      source(conn),
      " command=",
      command(conn),
      " version=",
      version(conn),
      " org=",
      org_tag(conn) || @na,
      " trace=",
      trace_id(conn) || @na
    ]
  end

  @doc """
  W3C trace-id from the `traceparent` header (`00-<trace-id>-<span-id>-<flags>`).
  sem-ai sends one per command, so `count(distinct trace)` grouped by command in
  the logs gives invocation counts — without paying the metric cardinality cost
  of putting a request id in a tag.
  """
  def trace_id(conn) do
    case header(conn, "traceparent") do
      tp when is_binary(tp) ->
        case String.split(tp, "-") do
          [_v, tid, _span, _flags | _] when byte_size(tid) == 32 -> tid
          _ -> nil
        end

      _ ->
        nil
    end
  end

  def source(conn) do
    case header(conn, "x-client-source") do
      src when src in @known_sources -> src
      _ -> "api"
    end
  end

  def status_label(status) when is_integer(status) and status >= 500, do: "server_error"
  def status_label(status) when is_integer(status) and status >= 400, do: "client_error"
  def status_label(status) when is_integer(status), do: "ok"
  def status_label(_status), do: "unknown"

  defp command(conn), do: sanitize(header(conn, "x-client-command"), @command_regex)
  defp version(conn), do: sanitize(header(conn, "x-client-version"), @version_regex)

  defp sanitize(value, regex) when is_binary(value) do
    if Regex.match?(regex, value), do: value, else: @na
  end

  defp sanitize(_value, _regex), do: @na

  # api.org_usage [org, source] — per-request API volume per org and flavour.
  # No dedup (this is volume, not invocation count); skipped when there is no
  # org (unauthenticated request).
  defp track_org_usage(conn, source) do
    case org_tag(conn) do
      nil -> :ok
      org -> Metrics.increment(@org_metric, [org, source])
    end
  end

  # Carbon (graphite) uses "." as the metric-path separator, so a tag VALUE
  # containing "." (e.g. a semver version) splits into extra path segments and
  # corrupts the measurement name. Neutralise it before it becomes a tag.
  defp graphite_safe(value), do: String.replace(value, ".", "_")

  defp header(conn, name) do
    conn
    |> Conn.get_req_header(name)
    |> List.first()
  end
end
