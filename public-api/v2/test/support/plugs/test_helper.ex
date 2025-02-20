defmodule Support.Plugs.TestHelper do
  # This function is defined only for simpler auth testing without OpenApiSpex CastAndValidate plug.
  # As params will have string keys, we need to convert them to atoms.
  @behaviour Plug

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    conn
    |> atomize_params()
  end

  defp atomize_params(conn = %Plug.Conn{query_params: %Plug.Conn.Unfetched{}}) do
    params =
      Plug.Conn.fetch_query_params(conn).params
      |> Enum.into(%{}, fn {k, v} -> {String.to_atom(k), v} end)

    %{conn | params: params}
  end
end
