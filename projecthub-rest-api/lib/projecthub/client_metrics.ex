defmodule Projecthub.ClientMetrics do
  @moduledoc """
  Per-request client attribution, emitted two ways from one before_send hook —
  the same contract as the v1alpha plug. Reads the `x-client-*` headers sem-ai
  attaches; header-less callers tag `source=api`, so both outputs cover all
  traffic, not only sem-ai.

  1. Watchman metrics:

     * `Projecthub.router.client_request` (timing) + `.<status>` (counter) —
       this app's per-service rich metric, tags `[source, command, version]`.
       Status is in the metric NAME because the statsd_graphite backend keeps
       only 3 positional tags.
     * `api.client_usage` `[source]` and `api.org_usage` `[org, source]` —
       generic, service-agnostic counters emitted with the *same* names by
       every backend, so they aggregate cross-service (the Watchman `service`
       tag, from each app's prefix, splits per backend). `org` is the auth-set
       `x-semaphore-org-id` (trusted, bounded by real orgs).

     Tag values are graphite-safe: `.`/`+` -> `_` so a value can't inject the
     carbon path separator and corrupt the measurement. `command`/`version`
     are regex-sanitised (charset + length) before they become tags.

  2. One structured JSON log line to stdout — keys: severity, message,
     client_source, client_command, client_version, client_org_id, status,
     duration_ms. Carries the full-fidelity values (raw dotted version) that
     don't belong in metric tags.
  """

  alias Plug.Conn

  @metric "Projecthub.router.client_request"
  @usage_metric "api.client_usage"
  @org_metric "api.org_usage"
  @na "na"
  @known_sources ~w(semai-cli semai-mcp)
  @command_regex ~r/\A[a-z0-9_-]{1,50}\z/
  @version_regex ~r/\A[A-Za-z0-9._+-]{1,30}\z/

  @doc """
  Register a before_send hook that submits the metrics and emits the JSON
  event line once the response status is known.
  """
  @spec track_request(Conn.t()) :: Conn.t()
  def track_request(conn) do
    start = System.monotonic_time(:millisecond)
    tags = client_tags(conn)
    [src | _] = tags

    Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time(:millisecond) - start

      Watchman.submit({@metric, tags}, duration, :timing)
      Watchman.increment({metric_name(conn.status), tags})
      Watchman.increment({@usage_metric, [src]})
      track_org_usage(conn, src)

      event = %{
        severity: "INFO",
        message: "client_request",
        client_source: source(conn),
        client_command: command(conn),
        client_version: version(conn),
        client_org_id: org_id(conn),
        status: conn.status,
        duration_ms: duration
      }

      IO.puts(Jason.encode!(event))
      conn
    end)
  end

  @doc "Positional Watchman tags [source, command, version], graphite-safe."
  def client_tags(conn),
    do: [source(conn), command(conn), version(conn)] |> Enum.map(&graphite_safe/1)

  @doc "Status-suffixed metric name, e.g. \"...client_request.ok\"."
  def metric_name(status), do: "#{@metric}.#{status_label(status)}"

  @spec source(Conn.t()) :: String.t()
  def source(conn) do
    case header(conn, "x-client-source") do
      src when src in @known_sources -> src
      _ -> "api"
    end
  end

  @doc """
  Org identity from the auth-set `x-semaphore-org-id` header (trusted, stable,
  never client-supplied). Returns `"na"` when unauthenticated.
  """
  @spec org_id(Conn.t()) :: String.t()
  def org_id(conn) do
    case header(conn, "x-semaphore-org-id") do
      id when is_binary(id) and id != "" -> id
      _ -> @na
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
    case org_id(conn) do
      @na -> :ok
      org -> Watchman.increment({@org_metric, [graphite_safe(org), source]})
    end
  end

  # "." is the carbon path separator and "+" is reserved-ish; both -> "_" so a
  # tag value can't corrupt the measurement path.
  defp graphite_safe(value), do: String.replace(value, ~r/[.+]/, "_")

  defp header(conn, name) do
    conn
    |> Conn.get_req_header(name)
    |> List.first()
  end
end
