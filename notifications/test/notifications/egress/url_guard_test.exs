defmodule Notifications.Egress.UrlGuardTest do
  use ExUnit.Case, async: true

  alias Notifications.Egress.UrlGuard

  describe "verify/1 - allowed (public) destinations" do
    test "public https webhook passes" do
      assert UrlGuard.verify("https://public.example.test/hook") == :ok
    end

    test "public http webhook passes" do
      assert UrlGuard.verify("http://public.example.test/hook") == :ok
    end

    test "Slack incoming-webhook host passes" do
      assert UrlGuard.verify("https://hooks.slack.com/services/T00/B00/xxxx") == :ok
    end

    test "public IPv4 literal passes" do
      assert UrlGuard.verify("https://93.184.216.34/hook") == :ok
    end

    test "public IPv6 literal passes" do
      assert UrlGuard.verify("https://[2606:2800:220:1:248:1893:25c8:1946]/hook") == :ok
    end

    test "url with a path, query and port still passes" do
      assert UrlGuard.verify("https://public.example.test:8443/a/b?x=1&y=2") == :ok
    end
  end

  describe "verify/1 - blocked private / metadata / reserved destinations" do
    test "localhost hostname is blocked" do
      assert {:error, _} = UrlGuard.verify("http://localhost/")
    end

    test "127.0.0.1 loopback literal is blocked" do
      assert {:error, {:blocked_ip, {127, 0, 0, 1}}} = UrlGuard.verify("http://127.0.0.1/")
    end

    test "127.x anywhere in loopback range is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://127.9.9.9/")
    end

    test "cloud metadata 169.254.169.254 is blocked" do
      assert {:error, {:blocked_ip, {169, 254, 169, 254}}} =
               UrlGuard.verify("http://169.254.169.254/latest/meta-data/")
    end

    test "link-local 169.254.x is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://169.254.1.1/")
    end

    test "RFC1918 10.0.0.0/8 literal is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://10.1.2.3/")
    end

    test "RFC1918 172.16.0.0/12 literal is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://172.16.5.5/")
    end

    test "172.32.x (outside the /12) is public and allowed" do
      assert UrlGuard.verify("http://172.32.5.5/") == :ok
    end

    test "RFC1918 192.168.0.0/16 literal is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://192.168.1.1/")
    end

    test "CGNAT 100.64.0.0/10 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://100.64.1.1/")
    end

    test "0.0.0.0/8 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://0.0.0.0/")
    end

    test "multicast 224/4 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://224.0.0.1/")
    end

    test "reserved 240/4 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://240.0.0.1/")
    end

    test "broadcast 255.255.255.255 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://255.255.255.255/")
    end

    test "IPv6 loopback ::1 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://[::1]/")
    end

    test "IPv6 link-local fe80::/10 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://[fe80::1]/")
    end

    test "IPv6 ULA fc00::/7 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://[fd00::1]/")
    end

    test "IPv4-mapped IPv6 ::ffff:127.0.0.1 is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://[::ffff:127.0.0.1]/")
    end

    test "IPv4-mapped IPv6 ::ffff:169.254.169.254 metadata is blocked" do
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://[::ffff:169.254.169.254]/")
    end

    test "6to4 wrapping a private v4 (2002:a00:1::) is blocked" do
      # 2002:0a00:0001:: embeds 10.0.0.1
      assert {:error, {:blocked_ip, _}} = UrlGuard.verify("http://[2002:a00:1::]/")
    end
  end

  describe "verify/1 - hostname that resolves to a private IP" do
    test "hostname resolving to 10.x is blocked" do
      assert {:error, {:blocked_ip, {10, 0, 0, 5}}} =
               UrlGuard.verify("https://private.internal.test/hook")
    end

    test "hostname resolving to metadata IP is blocked" do
      assert {:error, {:blocked_ip, {169, 254, 169, 254}}} =
               UrlGuard.verify("https://metadata.internal.test/hook")
    end

    test "hostname with a mix of public and private A records is blocked" do
      assert {:error, {:blocked_ip, {10, 0, 0, 5}}} =
               UrlGuard.verify("https://mixed.evil.test/hook")
    end

    test "unresolvable hostname fails closed" do
      assert {:error, :unresolvable} = UrlGuard.verify("https://does-not-exist.internal.test/")
    end
  end

  describe "verify/1 - syntactic rejection" do
    test "non-http scheme is rejected" do
      assert {:error, :bad_scheme} = UrlGuard.verify("file:///etc/passwd")
      assert {:error, :bad_scheme} = UrlGuard.verify("gopher://public.example.test/")
      assert {:error, :bad_scheme} = UrlGuard.verify("ftp://public.example.test/")
    end

    test "missing host is rejected" do
      assert {:error, :missing_host} = UrlGuard.verify("https:///path-only")
    end

    test "literal CR/LF in the URL is rejected (header/CRLF injection)" do
      assert {:error, :control_char} =
               UrlGuard.verify("https://public.example.test/\r\nX-Injected: 1")
    end

    test "NUL byte in the URL is rejected" do
      assert {:error, :control_char} = UrlGuard.verify("https://public.example.test/\0")
    end

    test "percent-encoded CRLF in the host is rejected after decoding" do
      assert {:error, :control_char} = UrlGuard.verify("https://public.example.test%0d%0aevil/")
    end

    test "non-string input is rejected" do
      assert {:error, :bad_url} = UrlGuard.verify(nil)
      assert {:error, :bad_url} = UrlGuard.verify(:not_a_url)
    end
  end

  describe "blocked?/1" do
    test "classifies representative v4 addresses" do
      assert UrlGuard.blocked?({127, 0, 0, 1})
      assert UrlGuard.blocked?({10, 0, 0, 1})
      assert UrlGuard.blocked?({192, 168, 0, 1})
      assert UrlGuard.blocked?({169, 254, 169, 254})
      refute UrlGuard.blocked?({8, 8, 8, 8})
      refute UrlGuard.blocked?({1, 1, 1, 1})
    end
  end
end
