defmodule Ppl.OrgClient do
  @moduledoc """
  gRPC client consuming Organization API
  """

  @watchman_prefix_key "Ppl.OrgClient"
  @url_env_var "INTERNAL_API_URL_ORGANIZATION"
  @timeout 3_000

  alias InternalApi.Organization, as: API
  alias API.OrganizationService, as: Service
  require Logger

  @type settings() :: %{String.t() => String.t()}

  @doc """
  Calls Organization gRPC API to fetch organization settings
  Returns a map with string keys, arranging settings in a dictionary structure.
  Check organization.proto for more details
  """
  @spec fetch_settings(String.t()) :: {:ok, settings()} | {:error, :timeout} | {:error, any()}
  def fetch_settings(organization_id) do
    result =
      Wormhole.capture(__MODULE__, :do_fetch_settings, [organization_id],
        stacktrace: true,
        timeout: @timeout
      )

    case result do
      {:ok, result} ->
        {:ok, result}

      {:error, {:timeout, timeout}} ->
        log_timeout(organization_id, timeout)
        {:error, :timeout}

      {:error, {:shutdown, {reason, _stacktrace}}} ->
        log_shutdown(organization_id, reason)
        {:error, reason}
    end
  end

  #
  # gRPC connection
  #

  @doc false
  def do_fetch_settings(organization_id) do
    Watchman.benchmark("#{@watchman_prefix_key}.fetch_organization_settings.duration", fn ->
      request = API.FetchOrganizationSettingsRequest.new(org_id: organization_id)

      case send_request(request) do
        {:ok, response} ->
          Watchman.increment("#{@watchman_prefix_key}.fetch_organization_settings.success")
          settings_from_response(response)

        {:error, reason} ->
          Watchman.increment("#{@watchman_prefix_key}.fetch_organization_settings.failure")
          raise reason
      end
    end)
  end

  defp send_request(request) do
    url =
      System.get_env(@url_env_var) || raise "environment variable #{@url_env_var} was not found"

    with {:ok, channel} <- GRPC.Stub.connect(url) do
      Watchman.increment("#{@watchman_prefix_key}.fetch_organization_settings.connect")

      try do
        Service.Stub.fetch_organization_settings(channel, request)
      after
        GRPC.Stub.disconnect(channel)
      end
    end
  end

  #
  # Response parsing
  #

  defp settings_from_response(response) do
    response
    |> Util.Proto.to_map!()
    |> case do
      %{settings: settings} ->
        Enum.into(settings, %{}, &{&1.key, &1.value})
    end
  end

  #
  # Logging functions
  #

  defp log_timeout(organization_id, _timeout) do
    metadata = log_metadata(organization_id: organization_id)
    Logger.error("Ppl.OrgClient.fetch_settings/2: TIMEOUT #{metadata}")
  end

  defp log_shutdown(organization_id, reason) do
    metadata = log_metadata(organization_id: organization_id, reason: reason)
    Logger.error("Ppl.OrgClient.fetch_settings/2: SHUTDOWN #{metadata}")
  end

  defp log_metadata(metadata) do
    formatter = &"#{elem(&1, 0)}=#{inspect(elem(&1, 1))}"
    metadata |> Enum.map_join(" ", formatter)
  end
end
