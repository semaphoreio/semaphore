defmodule HooksReceiver.LicenseClient do
  @moduledoc """
  Client for communicating with the license-checker gRPC service.
  """

  alias InternalApi.License.{VerifyLicenseRequest, VerifyLicenseResponse, LicenseService.Stub}

  require Logger

  @cache_name :license_cache
  @cache_ttl :timer.minutes(5) # 5 minute cache TTL

  @doc """
  Verifies a license using the license-checker service.

  ## Parameters
    * opts - Optional keyword list of options
      * :use_cache? - Whether to use cache (default: true)
      * :reload_cache? - Whether to force reload cache (default: false)

  ## Returns
    * {:ok, response} - Where response is a VerifyLicenseResponse struct
    * {:error, reason} - If there was an error communicating with the service
  """
  @spec verify_license(Keyword.t()) :: {:ok, VerifyLicenseResponse.t()} | {:error, any()}
  def verify_license(opts \\ []) do
    request = %VerifyLicenseRequest{}
    use_cache? = Keyword.get(opts, :use_cache?, true)
    reload_cache? = Keyword.get(opts, :reload_cache?, false)
    cache_key = "license_verification"

    if reload_cache?, do: Cachex.del(@cache_name, cache_key)

    if use_cache? do
      case Cachex.get(@cache_name, cache_key) do
        {:ok, nil} ->
          do_verify_license(request, cache_key)

        {:ok, result} ->
          {:ok, result}

        _ ->
          do_verify_license(request, cache_key)
      end
    else
      do_verify_license(request)
    end
  end

  defp do_verify_license(request, cache_key \\ nil) do
    case connect() do
      {:ok, channel} ->
        try do
          case Stub.verify_license(channel, request, []) do
            {:ok, response} = result ->
              if cache_key do
                # Store successful responses in cache
                Cachex.put(@cache_name, cache_key, response, ttl: @cache_ttl)
              end
              result

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
  Invalidates the license verification cache.
  """
  def invalidate_cache do
    Cachex.del(@cache_name, "license_verification")
  end

  @doc """
  Establishes a connection to the license-checker gRPC service.
  """
  @spec connect() :: {:ok, GRPC.Channel.t()} | {:error, any()}
  def connect do
    GRPC.Stub.connect(url())
  end

  defp url, do: Application.get_env(:hooks_receiver, :license_checker_grpc)
end
