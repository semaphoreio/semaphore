defmodule HooksReceiver.LicenseClientTest do
  use ExUnit.Case, async: true

  alias HooksReceiver.LicenseClient

  setup do
    Application.put_env(:hooks_receiver, :license_checker_grpc, "localhost:50051")
    :ok
  end

  test "returns {:ok, response} when license is valid" do
    LicenseMock
    |> GrpcMock.expect(:verify_license, fn _channel, _stream ->
      %InternalApi.License.VerifyLicenseResponse{valid: true, message: "ok", expires_at: nil}
    end)

    result = LicenseClient.verify_license()
    assert {:ok, %InternalApi.License.VerifyLicenseResponse{valid: true, message: "ok"}} = result
    GrpcMock.verify!(LicenseMock)
  end

  test "returns {:error, reason} on error" do
    LicenseMock
    |> GrpcMock.expect(:verify_license, fn _channel, _stream ->
      raise GRPC.RPCError,
        status: :unavailable,
        message: ""
    end)

    result = LicenseClient.verify_license()
    assert {:error, :unavailable} = result
    GrpcMock.verify!(LicenseMock)
  end
end
