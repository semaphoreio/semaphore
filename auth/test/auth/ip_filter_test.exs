defmodule Auth.IpFilterTest do
  use ExUnit.Case
  use Plug.Test

  @org_id UUID.uuid4()

  describe "#block?" do
    test "empty ip_allow_list => returns false" do
      conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs")

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: []
             })
    end

    test "no X-Forwarded-For header => returns false" do
      conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs")

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["172.14.101.99"]
             })
    end

    test "bad X-Forwarded-For header => returns false" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "999.999.999.999"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["172.14.101.99"]
             })
    end

    test "single bad IP => returns false" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "172.14.101.99"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["999.999.999.999"]
             })
    end

    test "single IP => returns false if request comes from the same IP" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "172.14.101.99"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["172.14.101.99"]
             })
    end

    test "single IP => returns true if request does not come from the same IP" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "211.191.11.4"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      assert Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["172.14.101.99"]
             })
    end

    test "multiple IPs => returns false if request comes from one of the IPs allowed" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "172.14.101.99"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12", "172.14.101.99"]
             })
    end

    test "multiple IPs => returns true if request comes from none of the IPs allowed" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "211.191.11.4"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      assert Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12", "172.14.101.99"]
             })
    end

    test "single bad CIDR => returns false" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "172.14.101.99"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12/999"]
             })
    end

    test "single CIDR => returns false if request comes from IP inside CIDR" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "32.109.221.1"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12/28"]
             })
    end

    test "single CIDR => returns true if request comes from IP outside the CIDR" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "32.109.222.1"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      assert Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["32.109.221.12/28"]
             })
    end

    test "multiple CIDRs => returns false if request comes from IP inside one of the CIDRs" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "32.109.221.1"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.0/16", "32.109.221.12/28"]
             })
    end

    test "multiple CIDRs => returns true if request comes from IP outside all CIDRs" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "45.111.201.7"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      assert Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.0/16", "32.109.221.12/28"]
             })
    end

    test "IP + CIDR => returns false if request comes from IP inside CIDR" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "32.109.221.1"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.12", "32.109.221.12/28"]
             })
    end

    test "IP + CIDR => returns false if request comes from one of the allowed IPs" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "113.51.211.12"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      refute Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.12", "32.109.221.12/28"]
             })
    end

    test "IP + CIDR => returns true if request comes from IP not in CIDRs and not in allowed IPs" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "35.121.222.37"}]},
          :get,
          "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs",
          nil
        )

      assert Auth.IpFilter.block?(conn, %{
               id: @org_id,
               name: "semaphore",
               ip_allow_list: ["113.51.211.12", "32.109.221.12/28"]
             })
    end
  end
end
