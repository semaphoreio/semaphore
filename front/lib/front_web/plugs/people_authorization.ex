defmodule FrontWeb.Plugs.PeopleAuthorization do
  alias Front.Auth

  def init(default), do: default

  def call(conn, _) do
    conn
    |> authorize
  end

  defp authorize(conn) do
    Auth.private(conn, :ManagePeople)
  end
end
