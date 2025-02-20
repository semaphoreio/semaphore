defmodule Ppl.PFCClient do
  @moduledoc """
  gRPC client consuming pre-flight checks API
  """

  @watchman_prefix_key "Ppl.PFCClient.describe"
  @url_env_var "INTERNAL_API_URL_PFC"
  @timeout 3_000

  alias InternalApi.PreFlightChecksHub, as: API
  alias API.PreFlightChecksService, as: Service
  require Logger

  @type pfcs() :: %{
          binary() => nil | %{binary() => any()}
        }

  @doc """
  Calls pre-flight checks hub via gRPC API to fetch pre-flight checks
  Returns a map with (nested) string keys:
  - "organization_pfc" - contains organization-level pre-flight checks
  - "project_pfc" - contains project-level pre-flight checks
  If pre-flight checks for any level are not defined, it's set as nil.
  Otherwise, a complete definition is provided.

  Check pre_flight_checks_hub.proto for more details
  """
  @spec describe(String.t(), String.t()) :: {:ok, pfcs()} | {:error, :timeout} | {:error, any()}
  def describe(organization_id, project_id) do
    if System.get_env("SKIP_PFC") == "true" do
      {:ok, %{"organization_pfc" => nil, "project_pfc" => nil}}
    else
      _describe(organization_id, project_id)
    end
  end

  defp _describe(organization_id, project_id) do
    result =
      Wormhole.capture(
        __MODULE__,
        :do_describe,
        [organization_id, project_id],
        stacktrace: true,
        timeout: @timeout
      )

    case result do
      {:ok, result} ->
        {:ok, result}

      {:error, {:timeout, timeout}} ->
        log_timeout(organization_id, project_id, timeout)
        {:error, :timeout}

      {:error, {:shutdown, {reason, _stacktrace}}} ->
        log_shutdown(organization_id, project_id, reason)
        {:error, reason}
    end
  end

  #
  # gRPC connection
  #

  @doc false
  def do_describe(organization_id, project_id) do
    Watchman.benchmark("#{@watchman_prefix_key}.duration", fn ->
      request = new_request(organization_id, project_id)

      case send_request(request) do
        {:ok, response} ->
          Watchman.increment("#{@watchman_prefix_key}.success")
          pfcs_from_response(response)

        {:error, reason} ->
          Watchman.increment("#{@watchman_prefix_key}.failure")
          raise reason
      end
    end)
  end

  defp new_request(organization_id, project_id) do
    Util.Proto.deep_new!(
      API.DescribeRequest,
      level: :EVERYTHING,
      organization_id: organization_id,
      project_id: project_id
    )
  end

  defp send_request(request) do
    url =
      System.get_env(@url_env_var) || raise "environment variable #{@url_env_var} was not found"

    with {:ok, channel} <- GRPC.Stub.connect(url) do
      Watchman.increment("#{@watchman_prefix_key}.connect")

      try do
        Service.Stub.describe(channel, request)
      after
        GRPC.Stub.disconnect(channel)
      end
    end
  end

  #
  # Response parsing
  #

  defp pfcs_from_response(response) do
    response
    |> Util.Proto.to_map!(string_keys: true)
    |> case do
      %{"status" => %{"code" => :OK}, "pre_flight_checks" => pfcs} ->
        Enum.into(pfcs, %{}, &pfc_from_response/1)

      %{"status" => %{"code" => :NOT_FOUND}} ->
        :undefined
    end
  end

  defp pfc_from_response({"organization_pfc", pfc}) when is_map(pfc),
    do: {"organization_pfc", Map.take(pfc, ~w(commands secrets))}

  defp pfc_from_response({"project_pfc", pfc}) when is_map(pfc),
    do: {"project_pfc", Map.take(pfc, ~w(commands secrets agent))}

  defp pfc_from_response({key, nil}), do: {to_string(key), nil}

  #
  # Logging functions
  #

  defp log_timeout(organization_id, project_id, _timeout) do
    metadata =
      log_metadata(
        organization_id: organization_id,
        project_id: project_id
      )

    Logger.error("Ppl.PFCClient.describe/2: TIMEOUT #{metadata}")
  end

  defp log_shutdown(organization_id, project_id, reason) do
    metadata =
      log_metadata(
        organization_id: organization_id,
        project_id: project_id,
        reason: reason
      )

    Logger.error("Ppl.PFCClient.describe/2: SHUTDOWN #{metadata}")
  end

  defp log_metadata(metadata) do
    formatter = &"#{elem(&1, 0)}=#{inspect(elem(&1, 1))}"
    metadata |> Enum.map_join(" ", formatter)
  end
end
