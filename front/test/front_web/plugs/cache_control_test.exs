defmodule FrontWeb.Plugs.CacheControlTest do
  use FrontWeb.ConnCase
  doctest FrontWeb.Plugs.CacheControl
  alias FrontWeb.Plugs.CacheControl

  describe "CacheControl plug" do
    test "can be set to not store the cache at all", %{conn: conn} do
      conn = CacheControl.call(conn, :no_cache)
      assert Plug.Conn.get_resp_header(conn, "cache-control") == ["no-cache, no-store"]
    end

    test "can be set to cache response for a private session", %{conn: conn} do
      conn = CacheControl.call(conn, :private_cache)

      assert Plug.Conn.get_resp_header(conn, "cache-control") == [
               "no-cache, private, must-revalidate"
             ]
    end

    test "can be set to use etag-friendly caching", %{conn: conn} do
      conn = CacheControl.call(conn, :etag_cache)

      assert Plug.Conn.get_resp_header(conn, "cache-control") == [
               "private, max-age=0, must-revalidate"
             ]
    end
  end
end
