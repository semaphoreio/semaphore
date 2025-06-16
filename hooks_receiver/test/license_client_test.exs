defmodule HooksReceiver.LicenseClientTest do
  use ExUnit.Case, async: true

  alias HooksReceiver.LicenseClient
  alias InternalApi.License.VerifyLicenseResponse

  @valid_response %VerifyLicenseResponse{valid: true, message: "ok", expires_at: nil}

  setup do
    Application.put_env(:hooks_receiver, :license_checker_grpc, "localhost:50051")
    # Clear cache before each test
    Cachex.clear(:license_cache)
    :ok
  end

  test "returns {:ok, response} when license is valid" do
    LicenseMock
    |> GrpcMock.expect(:verify_license, fn _channel, _stream ->
      @valid_response
    end)

    result = LicenseClient.verify_license()
    assert {:ok, %VerifyLicenseResponse{valid: true, message: "ok"}} = result
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

  describe "caching" do
    test "returns cached valid license even if actual license becomes invalid" do
      # First call returns valid license and caches it
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _stream ->
        @valid_response
      end)

      result1 = LicenseClient.verify_license()
      assert {:ok, %VerifyLicenseResponse{valid: true, message: "ok"}} = result1
      GrpcMock.verify!(LicenseMock)

      # If we were to call the service again, it would return invalid
      # (but we won't because the cache is valid)
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _stream ->
        %VerifyLicenseResponse{valid: false, message: "license expired", expires_at: nil}
      end)

      # Second call should use cache and return the valid license
      result2 = LicenseClient.verify_license()
      assert result2 == result1
      assert {:ok, %VerifyLicenseResponse{valid: true, message: "ok"}} = result2

      # Verify that the second mock was never called
      assert_raise GrpcMock.VerificationError, fn ->
        GrpcMock.verify!(LicenseMock)
      end
    end

    test "caches successful responses" do
      # First call should hit the service
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _stream ->
        @valid_response
      end)

      result1 = LicenseClient.verify_license()
      assert {:ok, %VerifyLicenseResponse{valid: true}} = result1
      GrpcMock.verify!(LicenseMock)

      # Second call should use cache (no mock expectation needed)
      result2 = LicenseClient.verify_license()
      assert result2 == result1
    end

    test "bypasses cache when use_cache? is false" do
      # Set up two separate calls to the service
      LicenseMock
      |> GrpcMock.expect(:verify_license, 2, fn _channel, _stream ->
        @valid_response
      end)

      # First call
      result1 = LicenseClient.verify_license(use_cache?: false)
      assert {:ok, %VerifyLicenseResponse{valid: true}} = result1

      # Second call should also hit the service
      result2 = LicenseClient.verify_license(use_cache?: false)
      assert result2 == result1

      GrpcMock.verify!(LicenseMock)
    end
  end
end
