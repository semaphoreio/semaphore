defmodule Front.Clients.License do
  @moduledoc """
  Client for communicating with the license-checker gRPC service.
  """
  require Logger

  alias InternalApi.License.{VerifyLicenseRequest, VerifyLicenseResponse, LicenseService.Stub}

  @version ["lib/internal_api/license.pb.ex"]
           |> Enum.map_join(".", fn file ->
             File.read(file)
             |> elem(1)
             |> then(&:crypto.hash(:md5, &1))
           end)
           |> Base.encode64()

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
    # 5 minute cache TTL
    ttl = :timer.minutes(5)
    key = cache_key(:verify_license, request)

    if reload_cache?, do: Front.Cache.unset(key)

    call = fn ->
      case connect() do
        {:ok, channel} ->
          do_verify_license(channel, request, use_cache?, ttl, key)

        {:error, reason} ->
          {:error, reason}
      end
    end

    if use_cache? do
      Front.Cache.get(key)
      |> case do
        {:ok, result} ->
          {:ok, Front.Cache.decode(result)}

        {:not_cached, _} ->
          call.()
      end
    else
      call.()
    end
  end

  @doc """
  Invalidates the cache for verify_license operation.
  """
  def invalidate_cache do
    cache_key(:verify_license, %VerifyLicenseRequest{})
    |> Front.Cache.unset()
  end

  @doc """
  Generates a cache key for the given operation and parameters.
  """
  def cache_key(operation, params) when not is_list(params), do: cache_key(operation, [params])

  def cache_key(operation, params) do
    id =
      Enum.map_join(params, "-", &inspect(&1))
      |> :erlang.term_to_binary(compressed: 6)
      |> Base.encode64()

    "license/#{@version}/#{operation}/#{id}"
  end

  defp do_verify_license(channel, request, use_cache?, ttl, key) do
    case Stub.verify_license(channel, request, []) do
      {:ok, response} = result when use_cache? ->
        set_cache(key, response, ttl)
        result

      {:ok, _response} = result ->
        result

      {:error, _} = error ->
        error
    end
  rescue
    error ->
      {:error, {:rescue, error}}
  catch
    kind, reason ->
      {:error, {kind, reason}}
  end

  defp set_cache(key, response, ttl) do
    Front.Async.run(fn ->
      Front.Cache.set(key, Front.Cache.encode(response), ttl)
    end)
  end

  @doc """
  Establishes a connection to the license-checker gRPC service.
  """
  @spec connect() :: {:ok, GRPC.Channel.t()} | {:error, any()}
  def connect do
    Application.fetch_env!(:front, :license_grpc_endpoint)
    |> GRPC.Stub.connect()
  end
end
