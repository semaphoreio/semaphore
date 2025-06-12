defmodule HooksReceiver.LicenseClient do
  @moduledoc """
  Client for communicating with the license-checker gRPC service.
  """

  alias InternalApi.License.{VerifyLicenseRequest, VerifyLicenseResponse, LicenseService.Stub}

  require Logger

  @doc """
  Verifies a license using the license-checker service.

  ## Parameters
    * None

  ## Returns
    * {:ok, response} - Where response is a VerifyLicenseResponse struct
    * {:error, reason} - If there was an error communicating with the service
  """
  @spec verify_license ::
          {:ok, VerifyLicenseResponse.t()} | {:error, any()}
  def verify_license do
    request = %VerifyLicenseRequest{}

    case connect() do
      {:ok, channel} ->
        try do
          case Stub.verify_license(channel, request, []) do
            {:ok, response} ->
              {:ok, response}

            {:error, error} ->
              Logger.error("LicenseClient.verify_license: #{inspect(error)}")
              {:error, :unavailable}

            error ->
              Logger.error("LicenseClient.verify_license: unknown error: #{inspect(error)}")
              {:error, :unavailable}
          end
        catch
          kind, reason ->
            Logger.error("LicenseClient.verify_license: kind: #{kind}, reason: #{reason}")
            {:error, :unavailable}
        end

      {:error, reason} ->
        Logger.error("LicenseClient.verify_license: reason: #{reason}")
        {:error, :unavailable}
    end
  end

  @doc """
  Establishes a connection to the license-checker gRPC service.
  """
  @spec connect() :: {:ok, GRPC.Channel.t()} | {:error, any()}
  def connect do
    # The service is expected to run on port 50051
    GRPC.Stub.connect(url())
  end

  defp url, do: Application.get_env(:hooks_receiver, :license_checker_grpc)
end
