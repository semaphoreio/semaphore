defmodule Projecthub.ClientMetrics do
  @moduledoc """
  Per-request metric attributing projecthub-rest-api traffic by client (sem-ai
  CLI/MCP vs generic `api`), command, and version — the same contract as the
  v1alpha plug. Reads the `x-client-*` headers sem-ai attaches; header-less
  callers tag `source=api`, so the metric covers all traffic, not only sem-ai.

  Emits per request:

    * `Projecthub.router.client_request` (timing) + `.<status>` (counter) — this
      app's per-service rich metric, tags `[source, command, version]`. Status is
      in the metric NAME because the statsd_graphite backend keeps only 3
      positional tags.
    * `api.client_usage` `[source]` and `api.org_usage` `[org, source]` — generic,
      service-agnostic counters emitted with the *same* names by every backend,
      so they aggregate cross-service (the Watchman `service` tag, from this app's
      prefix, splits per backend). `org` comes from the auth-set
      `x-semaphore-org-*` headers (trusted, bounded cardinality).

  Tag values are graphite-safe: `.`/`+` -> `_` so a value can't inject the carbon
  path separator and corrupt the measurement. `command`/`version` are also
  regex-sanitised to bound cardinality.
  """

  alias Plug.Conn

  @metric "Projecthub.router.client_request"
  @usage_metric "api.client_usage"
  @org_metric "api.org_usage"
  @na "na"
  @known_sources ~w(semai-cli semai-mcp)
  @command_regex ~r/\A[a-z0-9_-]{1,50}\z/
  @version_regex ~r/\A[A-Za-z0-9._+-]{1,30}\z/

  @doc "Register a before_send hook that submits the timing + per-status counter."
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
      conn
    end)
  end

  @doc "Positional Watchman tags [source, command, version], graphite-safe."
  def client_tags(conn),
    do: [source(conn), command(conn), version(conn)] |> Enum.map(&graphite_safe/1)

  @doc "Status-suffixed metric name, e.g. \"...client_request.ok\"."
  def metric_name(status), do: "#{@metric}.#{status_label(status)}"

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

  @doc """
  Org identity from the auth-set headers (`x-semaphore-org-username`, else
  `-org-id`). Auth-set (trusted), not client, so cardinality is bounded by real
  orgs. nil when unauthenticated.
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

  defp command(conn), do: sanitize(header(conn, "x-client-command"), @command_regex)
  defp version(conn), do: sanitize(header(conn, "x-client-version"), @version_regex)

  defp sanitize(value, regex) when is_binary(value) do
    if Regex.match?(regex, value), do: value, else: @na
  end

  defp sanitize(_value, _regex), do: @na

  defp track_org_usage(conn, source) do
    case org_tag(conn) do
      nil -> :ok
      org -> Watchman.increment({@org_metric, [org, source]})
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
