defmodule Front.Clients.LicenseTest do
  use ExUnit.Case, async: false
  alias Front.Clients.License
  alias InternalApi.License.{VerifyLicenseRequest, VerifyLicenseResponse}

  @valid_response %VerifyLicenseResponse{
    valid: true,
    message: "ok",
    expires_at: nil,
    max_users: 50,
    enabled_features: []
  }

  setup do
    # Clear cache before each test
    Cacheman.clear(:front)

    :ok
  end

  describe "verify_license/1" do
    test "returns {:ok, response} when license is valid" do
      GrpcMock.stub(LicenseMock, :verify_license, @valid_response)

      result = License.verify_license()
      assert {:ok, %VerifyLicenseResponse{valid: true, message: "ok"}} = result
      GrpcMock.verify!(LicenseMock)
    end

    test "returns error when service is unavailable" do
      GrpcMock.stub(LicenseMock, :verify_license, fn _channel, _request ->
        raise GRPC.RPCError,
          status: GRPC.Status.internal(),
          message: "internal error"
      end)

      result = License.verify_license()
      assert {:error, %GRPC.RPCError{status: 13, message: "internal error"}} = result
      GrpcMock.verify!(LicenseMock)
    end
  end

  describe "caching" do
    test "returns cached valid license even if actual license becomes invalid" do
      # First call returns valid license and caches it
      LicenseMock
      |> GrpcMock.expect(:verify_license, fn _channel, _request ->
        @valid_response
      end)

      result1 = License.verify_license()
      assert match?({:ok, %VerifyLicenseResponse{valid: true, message: "ok"}}, result1)
      GrpcMock.verify!(LicenseMock)
      wait_for_cache!(cache_key())

      # Reset GrpcMock expectations
      GrpcMock.stub(LicenseMock, self(), InternalApi.License.LicenseService.Service)

      # If we were to call the service again, it would return invalid
      # (but we won't because the cache is valid)
      LicenseMock
      |> GrpcMock.expect(:verify_license, 1, fn _channel, _request ->
        %VerifyLicenseResponse{valid: false, message: "license expired", expires_at: nil}
      end)

      # Second call should use cache and return the valid license
      result2 = License.verify_license()
      assert result2 == result1
      assert match?({:ok, %VerifyLicenseResponse{valid: true, message: "ok"}}, result2)

      # Since we used the cache, the mock should still have its expectation unmet
      assert_raise GrpcMock.VerificationError, fn ->
        GrpcMock.verify!(LicenseMock)
      end
    end

    test "caches successful responses" do
      # First call should hit the service
      GrpcMock.stub(LicenseMock, :verify_license, @valid_response)

      result1 = License.verify_license()
      assert match?({:ok, %VerifyLicenseResponse{valid: true}}, result1)
      GrpcMock.verify!(LicenseMock)
      wait_for_cache!(cache_key())

      # Second call should use cache (no mock expectation needed)
      result2 = License.verify_license()
      assert match?({:ok, %VerifyLicenseResponse{valid: true}}, result2)

      # Verify no additional service calls were made
      GrpcMock.verify!(LicenseMock)
    end

    test "bypasses cache when use_cache? is false" do
      # Set up two separate calls to the service
      GrpcMock.stub(LicenseMock, :verify_license, @valid_response)

      # First call
      result1 = License.verify_license(use_cache?: false)
      assert match?({:ok, %VerifyLicenseResponse{valid: true}}, result1)

      # Second call should also hit the service
      result2 = License.verify_license(use_cache?: false)
      assert result2 == result1

      GrpcMock.verify!(LicenseMock)
    end

    test "reloads cache when reload_cache? is true" do
      # First call to populate cache
      GrpcMock.stub(LicenseMock, :verify_license, @valid_response)

      License.verify_license()
      GrpcMock.verify!(LicenseMock)
      wait_for_cache!(cache_key())

      # Second call with reload_cache?: true should hit the service again
      GrpcMock.stub(LicenseMock, :verify_license, %{@valid_response | message: "reloaded"})

      result = License.verify_license(reload_cache?: true)
      assert match?({:ok, %VerifyLicenseResponse{message: "reloaded"}}, result)
      GrpcMock.verify!(LicenseMock)
    end

    test "invalidate_cache clears the cache" do
      # First call to populate cache
      GrpcMock.stub(LicenseMock, :verify_license, @valid_response)

      License.verify_license()
      GrpcMock.verify!(LicenseMock)
      wait_for_cache!(cache_key())

      # Invalidate cache
      License.invalidate_cache()

      # Next call should hit the service again
      GrpcMock.stub(LicenseMock, :verify_license, %{@valid_response | message: "after invalidate"})

      result = License.verify_license()
      assert match?({:ok, %VerifyLicenseResponse{message: "after invalidate"}}, result)
      GrpcMock.verify!(LicenseMock)
    end

    test "does not cache error responses" do
      # First call returns an error
      GrpcMock.stub(LicenseMock, :verify_license, fn _channel, _request ->
        raise GRPC.RPCError,
          status: :unavailable,
          message: ""
      end)

      result1 = License.verify_license()
      assert {:error, %GRPC.RPCError{status: 14, message: ""}} = result1
      GrpcMock.verify!(LicenseMock)

      # Second call should hit the service again since errors aren't cached
      GrpcMock.stub(LicenseMock, :verify_license, @valid_response)

      result2 = License.verify_license()
      assert match?({:ok, %VerifyLicenseResponse{valid: true}}, result2)
      GrpcMock.verify!(LicenseMock)
    end
  end

  defp cache_key do
    License.cache_key(:verify_license, %VerifyLicenseRequest{})
  end

  defp wait_for_cache!(key, attempts \\ 20, delay_ms \\ 25) do
    case Front.Cache.get(key) do
      {:ok, _} ->
        :ok

      _ when attempts > 0 ->
        Process.sleep(delay_ms)
        wait_for_cache!(key, attempts - 1, delay_ms)

      _ ->
        flunk("license cache not set after waiting")
    end
  end
end
