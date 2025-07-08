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
      # First call to populate cache
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

    test "cache correctly encodes and decodes license responses" do
      # Convert DateTime to Google.Protobuf.Timestamp
      timestamp = %Google.Protobuf.Timestamp{
        seconds: DateTime.to_unix(~U[2025-12-31 23:59:59Z]),
        nanos: 0
      }

      response = %VerifyLicenseResponse{
        valid: true,
        message: "valid",
        enabled_features: ["feature1", "feature2"],
        max_users: 100,
        expires_at: timestamp
      }

      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _stream ->
        response
      end)

      # First call should cache the response
      {:ok, response1} = LicenseClient.verify_license()
      assert response1.valid
      assert response1.message == "valid"
      assert response1.enabled_features == ["feature1", "feature2"]
      assert response1.max_users == 100
      assert response1.expires_at.seconds == DateTime.to_unix(~U[2025-12-31 23:59:59Z])
      assert response1.expires_at.nanos == 0

      # Set up a mock that would return different data if called
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _stream ->
        %VerifyLicenseResponse{valid: false, message: "should not be called"}
      end)

      # Second call should get cached response with all fields intact
      {:ok, response2} = LicenseClient.verify_license()
      assert response2 == response1

      # Verify second mock was never called (used cache)
      assert_raise GrpcMock.VerificationError, fn ->
        GrpcMock.verify!(LicenseMock)
      end
    end
  end
end
