defmodule HooksReceiver.Plugs.LicenseVerifierTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias HooksReceiver.Plugs.LicenseVerifier

  @opts LicenseVerifier.init([])

  setup do
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
end
