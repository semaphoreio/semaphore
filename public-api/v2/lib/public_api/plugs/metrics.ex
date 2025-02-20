defmodule PublicAPI.Plugs.Metrics do
  @behaviour Plug
  @moduledoc """
  Plug for submitting metrics with watchman.
  Plug has to be placed before the handler plug and should contain tags
  """

  alias Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    name =
      if Keyword.has_key?(opts, :name) do
        Keyword.get(opts, :name)
      else
        "PublicAPI.router"
      end

    tags =
      if Keyword.has_key?(opts, :tags) do
        Keyword.get(opts, :tags)
      else
        []
      end

    start_time = System.monotonic_time(:millisecond)

    Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time(:millisecond) - start_time

      Watchman.submit({name, tags}, duration, :timing)

      cond do
        conn.status == 200 ->
          Watchman.increment({name, ["success"] ++ tags})

        conn.status >= 400 and conn.status < 500 ->
          Watchman.increment({name, ["client_error"] ++ tags})

        conn.status >= 500 ->
          Watchman.increment({name, ["server_error"] ++ tags})

        true ->
          Watchman.increment({name, ["unknown"] ++ tags})
      end

      conn
    end)
  end
end
