defmodule HooksReceiver.LicenseClient do
  @moduledoc """
  Client for communicating with the license-checker gRPC service.
  """

  alias InternalApi.License.{VerifyLicenseRequest, VerifyLicenseResponse, LicenseService.Stub}

  require Logger

  @cache_name :license_cache
  # 5 minute cache TTL
  @cache_ttl :timer.minutes(5)
  @cache_key "v1/license_verification"

  @doc """
  Verifies a license using the license-checker service.

  ## Parameters
    * opts - Optional keyword list of options
      * :use_cache? - Whether to use cache (default: true)

  ## Returns
    * {:ok, response} - Where response is a VerifyLicenseResponse struct
    * {:error, reason} - If there was an error communicating with the service
  """
  @spec verify_license(Keyword.t()) :: {:ok, VerifyLicenseResponse.t()} | {:error, any()}
  def verify_license(opts \\ []) do
    request = %VerifyLicenseRequest{}
    use_cache? = Keyword.get(opts, :use_cache?, true)

    if use_cache? do
      case Cachex.get(@cache_name, @cache_key) do
        {:ok, nil} ->
          do_verify_license(request)

        {:ok, result} ->
          {:ok, decode(result)}

        _ ->
          do_verify_license(request)
      end
    else
      do_verify_license(request)
    end
  end

  defp do_verify_license(request) do
    case connect() do
      {:ok, channel} ->
        do_verify_license(channel, request)

      {:error, reason} ->
        Logger.error("LicenseClient.verify_license: reason: #{reason}")
        {:error, :unavailable}
    end
  end

  defp do_verify_license(channel, request) do
    case Stub.verify_license(channel, request, []) do
      {:ok, response} = result ->
        encoded = encode(response)
        Cachex.put(@cache_name, @cache_key, encoded, ttl: @cache_ttl)
        result

      {:error, error} ->
        Logger.error("LicenseClient.verify_license: #{inspect(error)}")
        {:error, :unavailable}

      error ->
        Logger.error("LicenseClient.verify_license: unknown error: #{inspect(error)}")
        {:error, :unavailable}
    end
  rescue
    error ->
      Logger.error("LicenseClient.verify_license: rescue error: #{inspect(error)}")
      {:error, :unavailable}
  catch
    kind, reason ->
      Logger.error("LicenseClient.verify_license: kind: #{kind}, reason: #{reason}")
      {:error, :unavailable}
  end

  @doc """
  Establishes a connection to the license-checker gRPC service.
  """
  @spec connect() :: {:ok, GRPC.Channel.t()} | {:error, any()}
  def connect do
    GRPC.Stub.connect(url())
  end

  defp url, do: Application.get_env(:hooks_receiver, :license_checker_grpc)

  defp encode(data), do: :erlang.term_to_binary(data)
  defp decode(data), do: Plug.Crypto.non_executable_binary_to_term(data, [:safe])
end
