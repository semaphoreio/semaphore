defmodule CanvasFrontWeb.Plug.DevelopmentHeaders do
  import Plug.Conn
  alias Support.Stubs

  def init(options), do: options

  def call(conn, _opts) do
    #
    # stub x-semaphore-user-id and x-semaphore-org-id in development
    # The headers are only set if they are not already present.
    #

    conn =
      if set_anonymous_header?(conn) do
        put_req_header(conn, "x-semaphore-user-anonymous", "false")
      else
        conn
      end

    conn =
      if set_user_header?(conn) do
        put_req_header(conn, "x-semaphore-user-id", Stubs.User.default_user_id())
      else
        conn
      end

    conn =
      if set_org_header?(conn) do
        put_req_header(conn, "x-semaphore-org-id", Stubs.Organization.default_org_id())
      else
        conn
      end

    conn
  end

  defp set_anonymous_header?(conn) do
    get_req_header(conn, "x-semaphore-user-anonymous") == []
  end

  defp set_user_header?(conn) do
    get_req_header(conn, "x-semaphore-user-id") == [] and
      get_req_header(conn, "x-semaphore-user-anonymous") != ["true"]
  end

  defp set_org_header?(conn) do
    ## We don't set header on me.<DOMAIN> pages in tests
    domain = Application.fetch_env!(:canvas_front, :domain)

    not (conn.host =~ "me.#{domain}") and get_req_header(conn, "x-semaphore-org-id") == []
  end
end
