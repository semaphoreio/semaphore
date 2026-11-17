defmodule Notifications.Util.EndpointTest do
  use ExUnit.Case

  alias Notifications.Util.Endpoint

  describe ".validate_url" do
    test "accepts http and https URLs" do
      assert Endpoint.validate_url("https://hooks.slack.com/services/A/B/C") == :ok
      assert Endpoint.validate_url("http://example.com:8080/hook?a=1&b=%0d%0a") == :ok
      assert Endpoint.validate_url("https://user:pass@example.com/hook") == :ok
      assert Endpoint.validate_url("http://[2001:db8::1]:8080/hook") == :ok
    end

    test "rejects control characters, whitespace and non-ASCII anywhere in the URL" do
      for url <- [
            "https://example.com/hook?a=1\r\nX-Header: value",
            "https://example.com/ho\nok",
            "https://example.com/hook\0",
            "https://example.com/hook\t",
            "https://example.com/a b",
            "https://example.com/\x7F",
            "https://exämple.com/hook"
          ] do
        assert {:error, message} = Endpoint.validate_url(url)
        assert message =~ "characters that are not allowed"
      end
    end

    test "rejects schemes other than http and https" do
      for url <- [
            "http+unix://%2Fvar%2Frun%2Fdocker.sock/info",
            "ftp://example.com/file",
            "file:///etc/passwd",
            "gopher://example.com/",
            "example.com/hook",
            "//example.com/hook",
            "HTTPS://example.com/hook",
            "Http://example.com/hook"
          ] do
        assert {:error, message} = Endpoint.validate_url(url)
        assert message =~ "must start with http:// or https://"
      end
    end

    test "rejects URLs without a usable host" do
      for url <- [
            "http:///hook",
            "http://%31%32%37.0.0.1/hook",
            "http://evil.com?@127.0.0.1/"
          ] do
        assert {:error, message} = Endpoint.validate_url(url)
        assert message =~ "does not have a valid host"
      end
    end

    test "rejects non-string values" do
      assert {:error, _} = Endpoint.validate_url(nil)
      assert {:error, _} = Endpoint.validate_url(123)
    end
  end

  describe ".method" do
    test "defaults to POST" do
      assert Endpoint.method("") == {:ok, :post}
      assert Endpoint.method(nil) == {:ok, :post}
    end

    test "accepts POST, PUT and PATCH in any case" do
      assert Endpoint.method("POST") == {:ok, :post}
      assert Endpoint.method("post") == {:ok, :post}
      assert Endpoint.method("Put") == {:ok, :put}
      assert Endpoint.method("PATCH") == {:ok, :patch}
    end

    test "rejects anything else" do
      for action <- ["GET", "DELETE", "CONNECT", "post /x HTTP/1.1\r\nX: y\r\n\r\n", "POST "] do
        assert {:error, message} = Endpoint.method(action)
        assert message =~ "is not supported"
      end
    end
  end

  describe ".check_destination" do
    setup do
      previous = Application.get_env(:notifications, :block_internal_endpoints)
      Application.put_env(:notifications, :block_internal_endpoints, true)

      on_exit(fn -> Application.put_env(:notifications, :block_internal_endpoints, previous) end)
    end

    test "allows public addresses" do
      for url <- [
            "https://8.8.8.8/hook",
            "http://1.1.1.1:8080/hook",
            "https://[2606:4700:4700::1111]/hook",
            "https://[::ffff:8.8.8.8]/hook"
          ] do
        assert Endpoint.check_destination(url) == :ok, url
      end
    end

    test "refuses private, loopback, link-local and reserved addresses" do
      for url <- [
            "http://127.0.0.1/",
            "http://127.1/",
            "http://2130706433/",
            "http://0/",
            "http://0.0.0.0/",
            "http://10.0.0.1/",
            "http://172.16.0.1/",
            "http://172.31.255.255/",
            "http://192.168.1.1/",
            "http://100.64.0.1/",
            "http://100.100.100.200/",
            "http://169.254.0.1/",
            "http://198.18.0.1/",
            "http://224.0.0.1/",
            "http://255.255.255.255/",
            "http://[::]/",
            "http://[::1]/",
            "http://[::ffff:127.0.0.1]/",
            "http://[::ffff:10.0.0.1]/",
            "http://[::ffff:169.254.0.1]/",
            "http://[::ffff:0:7f00:1]/",
            "http://[::ffff:0:a9fe:1]/",
            "http://[::127.0.0.1]/",
            "http://[64:ff9b::a9fe:a9fe]/",
            "http://[64:ff9b:1::7f00:1]/",
            "http://[64:ff9b:1:0:7f:0:100:0]/",
            "http://[64:ff9b:1::808:808]/",
            "http://[fd00:ec2::254]/",
            "http://[fc00::1]/",
            "http://[fe80::1]/",
            "http://[ff02::1]/",
            "http://[2002:7f00:1::]/",
            "http://localhost:4000/",
            "http://evil.com;@127.0.0.1/"
          ] do
        assert {:error, message} = Endpoint.check_destination(url), url
        assert message =~ "not allowed"
      end
    end

    test "refuses hosts that do not resolve" do
      assert {:error, message} = Endpoint.check_destination("http://does-not-exist.invalid/")
      assert message =~ "could not be resolved"
    end

    test "still validates the URL" do
      assert {:error, _} = Endpoint.check_destination("http://8.8.8.8/?a=1\r\nX: y")
    end

    test "refuses internal addresses when the guard setting is missing" do
      Application.delete_env(:notifications, :block_internal_endpoints)

      assert {:error, message} = Endpoint.check_destination("http://127.0.0.1/")
      assert message =~ "not allowed"
    end

    test "allows internal addresses when the guard is turned off" do
      Application.put_env(:notifications, :block_internal_endpoints, false)

      assert Endpoint.check_destination("http://127.0.0.1/") == :ok
      assert Endpoint.check_destination("http://10.0.0.1/") == :ok
      assert {:error, _} = Endpoint.check_destination("http://10.0.0.1/?a=1\r\nX: y")
    end
  end
end
