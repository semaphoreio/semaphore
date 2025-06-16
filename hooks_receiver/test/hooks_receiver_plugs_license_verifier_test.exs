defmodule HooksReceiver.Plugs.LicenseVerifierTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias HooksReceiver.Plugs.LicenseVerifier

  @opts LicenseVerifier.init([])

  setup do
    Cachex.clear(:license_cache)

    on_exit(fn ->
      Application.delete_env(:hooks_receiver, :edition)
    end)

    :ok
  end

  test "bypasses verification if not EE" do
    Application.put_env(:hooks_receiver, :edition, "")
    conn = conn(:post, "/bitbucket")
    conn = LicenseVerifier.call(conn, @opts)
    assert conn.status == nil
  end

  test "allows request if license is valid" do
    Application.put_env(:hooks_receiver, :edition, "ee")

    LicenseMock
    |> GrpcMock.expect(:verify_license, fn _req, _stream ->
      %InternalApi.License.VerifyLicenseResponse{valid: true, message: "", expires_at: nil}
    end)

    conn = conn(:post, "/bitbucket")
    conn = LicenseVerifier.call(conn, @opts)
    assert conn.status == nil
    GrpcMock.verify!(LicenseMock)
  end

  test "rejects request if license is invalid" do
    Application.put_env(:hooks_receiver, :edition, "ee")

    LicenseMock
    |> GrpcMock.expect(:verify_license, fn _req, _stream ->
      %InternalApi.License.VerifyLicenseResponse{
        valid: false,
        message: "expired",
        expires_at: nil
      }
    end)

    conn = conn(:post, "/bitbucket")
    conn = LicenseVerifier.call(conn, @opts)
    assert conn.status == 403
    assert conn.resp_body == "License is not valid."
    GrpcMock.verify!(LicenseMock)
  end

  test "rejects request if license verification fails" do
    Application.put_env(:hooks_receiver, :edition, "ee")

    LicenseMock
    |> GrpcMock.expect(:verify_license, fn _req, _stream ->
      raise GRPC.RPCError,
        status: :unavailable,
        message: ""
    end)

    conn = conn(:post, "/bitbucket")
    conn = LicenseVerifier.call(conn, @opts)
    assert conn.status == 403
    assert conn.resp_body == "License is not valid."
    GrpcMock.verify!(LicenseMock)
  end

  describe "caching" do
    test "uses cached valid license for subsequent requests" do
      Application.put_env(:hooks_receiver, :edition, "ee")

      # First request should hit the service and cache the result
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _request ->
        %InternalApi.License.VerifyLicenseResponse{valid: true, message: "valid"}
      end)

      conn = conn(:post, "/bitbucket")
      conn = LicenseVerifier.call(conn, @opts)
      assert conn.status == nil
      GrpcMock.verify!(LicenseMock)

      # Reset GrpcMock expectations
      GrpcMock.stub(LicenseMock, self(), InternalApi.License.LicenseService.Service)

      # Second request should use cache and not hit the service
      # We set up a mock that would return invalid if called, to verify cache is used
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _request ->
        raise GRPC.RPCError,
          status: :unavailable,
          message: ""
      end)

      conn2 = conn(:post, "/bitbucket")
      conn2 = LicenseVerifier.call(conn2, @opts)
      # Request continues through the plug chain
      assert conn2.status == nil

      # Verify that the second mock was never called (cache was used)
      assert_raise GrpcMock.VerificationError, fn ->
        GrpcMock.verify!(LicenseMock)
      end
    end

    test "does not cache invalid license responses" do
      Application.put_env(:hooks_receiver, :edition, "ee")

      # First request returns invalid license
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _request ->
        raise GRPC.RPCError,
          status: :unavailable,
          message: ""
      end)

      conn = conn(:post, "/bitbucket")
      conn = LicenseVerifier.call(conn, @opts)
      assert conn.status == 403
      assert conn.resp_body == "License is not valid."
      GrpcMock.verify!(LicenseMock)

      # Reset GrpcMock expectations
      GrpcMock.stub(LicenseMock, self(), InternalApi.License.LicenseService.Service)

      # Second request should hit service again since invalid response wasn't cached
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _request ->
        %InternalApi.License.VerifyLicenseResponse{valid: true, message: "valid"}
      end)

      conn2 = conn(:post, "/bitbucket")
      conn2 = LicenseVerifier.call(conn2, @opts)
      # Request continues through the plug chain
      assert conn2.status == nil
      GrpcMock.verify!(LicenseMock)
    end
  end
end
