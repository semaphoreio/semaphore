defmodule Projecthub.ClientMetrics do
  @moduledoc """
  Emits one structured JSON log line per request to stdout. Downstream log
  ingestion turns these into metrics — no statsd/Watchman involved.

  Event keys: severity, message, client_source, client_command, client_version,
  client_org, status, duration_ms.
  """

  alias Plug.Conn

  @na "na"
  @known_sources ~w(semai-cli semai-mcp)
  @command_regex ~r/\A[a-z0-9_-]{1,50}\z/
  @version_regex ~r/\A[A-Za-z0-9._+-]{1,30}\z/

  @doc """
  Register a before_send hook that emits a JSON event line once the response
  status is known.
  """
  @spec track_request(Conn.t()) :: Conn.t()
  def track_request(conn) do
    start = System.monotonic_time(:millisecond)

    Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time(:millisecond) - start

      event = %{
        severity: "INFO",
        message: "client_request",
        client_source: source(conn),
        client_command: command(conn),
        client_version: version(conn),
        client_org: org(conn),
        status: conn.status,
        duration_ms: duration
      }

      IO.puts(Jason.encode!(event))
      conn
    end)
  end

  @spec source(Conn.t()) :: String.t()
  def source(conn) do
    case header(conn, "x-client-source") do
      src when src in @known_sources -> src
      _ -> "api"
    end
  end

  @doc """
  Org identity from the auth-set headers (`x-semaphore-org-username`, else
  `x-semaphore-org-id`). Returns `"na"` when unauthenticated.
  """
  @spec org(Conn.t()) :: String.t()
  def org(conn) do
    name = header(conn, "x-semaphore-org-username")
    id = header(conn, "x-semaphore-org-id")

    cond do
      is_binary(name) and name != "" -> name
      is_binary(id) and id != "" -> id
      true -> @na
    end
  end

  defp command(conn), do: sanitize(header(conn, "x-client-command"), @command_regex)
  defp version(conn), do: sanitize(header(conn, "x-client-version"), @version_regex)

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
