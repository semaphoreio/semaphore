defmodule TestLicenseChecker.Server do
  use GRPC.Server, service: InternalApi.License.LicenseService.Service

  @impl true
  def verify_license(_req, _stream) do
    # Default response, can be made dynamic with Agent if needed
    {:ok, %InternalApi.License.VerifyLicenseResponse{valid: true, message: "", expires_at: nil}}
  end
end
