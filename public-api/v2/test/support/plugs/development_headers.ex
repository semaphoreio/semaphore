defmodule Support.Plugs.DevelopmentHeaders do
  require Logger

  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    Logger.info("Setting development headers")

    org_id = Support.Stubs.Organization.default_org_id()
    org_username = Support.Stubs.Organization.default_org_username()
    user_id = Support.Stubs.User.default_user_id()

    conn
    |> maybe_set_header("x-semaphore-user-id", user_id)
    |> maybe_set_header("x-semaphore-org-id", org_id)
    |> maybe_set_header("x-semaphore-org-username", org_username)
  end

  defp maybe_set_header(conn, header, value) do
    if get_req_header(conn, header) == [] do
      Logger.info("Setting header #{header} to #{value}")
      put_req_header(conn, header, value)
    else
      conn
    end
  end
end
