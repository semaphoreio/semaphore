defmodule Front.Clients.License do
  @moduledoc """
  Client for communicating with the license-checker gRPC service.
  """

  alias InternalApi.License.{VerifyLicenseRequest, VerifyLicenseResponse, LicenseService.Stub}

  @doc """
  Verifies a license using the license-checker service.

  ## Parameters
    * None

  ## Returns
    * {:ok, response} - Where response is a VerifyLicenseResponse struct
    * {:error, reason} - If there was an error communicating with the service
  """
  @spec verify_license() ::
          {:ok, VerifyLicenseResponse.t()} | {:error, any()}
  def verify_license() do
    request = %VerifyLicenseRequest{}

    case connect() do
      {:ok, channel} ->
        try do
          case Stub.verify_license(channel, request, []) do
            {:ok, response} -> {:ok, response}
            {:error, error} -> {:error, error}
          end
        catch
          kind, reason ->
            {:error, {kind, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Establishes a connection to the license-checker gRPC service.
  """
  @spec connect() :: {:ok, GRPC.Channel.t()} | {:error, any()}
  def connect do
    # The service is expected to run on port 50051
    GRPC.Stub.connect("license-checker:50051")
  end
end
