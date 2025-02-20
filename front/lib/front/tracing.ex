defmodule Front.Tracing do
  def events(id) do
    Front.Tracing.Store.list(id)
  end

  def log(id, event, duration \\ nil) do
    Front.Tracing.Store.log(id, event, duration)
  end

  def track(id, event, f) do
    start = :os.system_time(:milli_seconds)

    log(id, "#{event}_started", nil)

    res = f.()

    ended = :os.system_time(:milli_seconds)

    log(id, "#{event}_ended", ended - start)

    res
  end

  def total_duratin(phoenix_call) do
    started_at = Front.Tracing.Store.start(phoenix_call.assigns.trace_id)

    :os.system_time(:milli_seconds) - started_at
  rescue
    _ -> -1
  end

  def report(phoenix_call) do
    log(phoenix_call.assigns.trace_id, :call_ended)

    rows =
      events(phoenix_call.assigns.trace_id)
      |> Enum.map_join(
        "\n",
        fn {name, at, duration} ->
          duration =
            if duration do
              "#{duration} ms"
            else
              "&mdash;"
            end

          """
          <tr>
            <td align=right>#{name}</td>
            <td align=right>#{at} ms</td>
            <td align=right>#{duration}</td>
          </tr>
          """
        end
      )

    """
    <style>
      #trace-table {
        border-collapse: collapse;
      }

      #trace-table td {
        padding: 4px;
      }
    </style>

    <table id="trace-table" width=100% border="1">
      <tr>
        <th>Event</th>
        <th>Timestamp (from call start)</th>
        <th>Event Duration</th>
      </tr>

      #{rows}
    </table>
    """
  end

  defmodule TracingPlug do
    import Plug.Conn

    def init(options), do: options

    def call(conn, _opts) do
      id = :os.system_time(:milli_seconds) |> Integer.to_string() |> inspect()

      conn = conn |> assign(:trace_id, id)

      Front.Tracing.log(conn.assigns.trace_id, :call_start)

      conn
    end
  end

  defmodule Store do
    use GenServer
    require Logger

    @tab :tracing

    def start_link(init_args \\ []) do
      GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
    end

    def log(id, event_name, duration) do
      case :ets.lookup(@tab, id) do
        [] ->
          event = {event_name, 0, duration}

          events = [event]

          :ets.insert(
            @tab,
            {id, [start: :os.system_time(:milli_seconds), events: events]}
          )

        [{_, [start: t, events: events]}] ->
          at = :os.system_time(:milli_seconds) - t
          event = {event_name, at, duration}

          events = events ++ [event]

          :ets.insert(@tab, {id, [start: t, events: events]})
      end
    end

    def start(id) do
      case :ets.lookup(@tab, id) do
        [] -> 0
        [{_, [start: t, events: _events]}] -> t
      end
    end

    def list(id) do
      case :ets.lookup(@tab, id) do
        [] ->
          []

        [{_, [start: _t, events: events]}] ->
          events
      end
    end

    def init(_) do
      :ets.new(@tab, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

      {:ok, %{}}
    end
  end
end
