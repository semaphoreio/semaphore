defmodule FrontWeb.Plug.ContentSecurityPolicyTest do
  use FrontWeb.ConnCase, async: true

  alias FrontWeb.Plug.ContentSecurityPolicy
  alias Plug.Conn

  setup do
    original_value = Application.get_env(:front, :csp_additional_connect_domains)

    on_exit(fn ->
      Application.put_env(:front, :csp_additional_connect_domains, original_value)
    end)

    :ok
  end

  describe "call/2" do
    test "adds default Content-Security-Policy header to conn", %{conn: conn} do
      result = ContentSecurityPolicy.call(conn, [])

      assert [header_value] = Conn.get_resp_header(result, "content-security-policy-report-only")
      assert header_value =~ "connect-src 'self'"
      assert header_value =~ "storage.googleapis.com"
    end

    test "includes additional domains from config in Content-Security-Policy", %{conn: conn} do
      Application.put_env(:front, :csp_additional_connect_domains, [
        "*.example.com",
        "*.example2.com"
      ])

      result = ContentSecurityPolicy.call(conn, [])

      assert [header_value] = Conn.get_resp_header(result, "content-security-policy-report-only")
      assert header_value =~ "connect-src 'self'"
      assert header_value =~ "*.example.com"
      assert header_value =~ "*.example2.com"
    end
  end
end
