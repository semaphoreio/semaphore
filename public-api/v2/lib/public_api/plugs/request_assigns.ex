defmodule PublicAPI.Plugs.RequestAssigns do
  @moduledoc """
  `PublicAPI.Plugs.RequestAssigns` is a Plug module responsible for extracting
  specific headers from the incoming HTTP request and assigning them to the connection (`conn`).
  The extracted headers are assigned to the `conn` under the keys
  `:organization_id`, `:organization_username`, `:user_id`, and `:user_agent` respectively.
  These can then be accessed later in the request handling pipeline.
  """

  @behaviour Plug

  alias Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> map_header("x-semaphore-org-id", :organization_id)
    |> map_header("x-semaphore-org-username", :organization_username)
    |> map_header("x-semaphore-user-id", :user_id)
    |> map_header("user-agent", :user_agent)
  end

  defp map_header(conn, header, name) do
    value =
      conn
      |> Conn.get_req_header(header)
      |> List.first()

    conn |> Conn.assign(name, value)
  end
end
