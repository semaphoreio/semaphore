defmodule Ppl.FeatureClient do
  @moduledoc """
  gRPC client consuming the Feature (FeatureHub) API.

  Used by `Ppl.FeatureHubProvider` to fetch the features enabled for an
  organization. Failures are turned into `{:error, _}` so callers can fail
  closed (treat the feature as disabled).
  """

  @watchman_prefix_key "Ppl.FeatureClient"
  @url_env_var "INTERNAL_API_URL_FEATURE"
  # This call sits in the pipeline initialization hot path (the compile task is
  # built and awaited inside a deadline-bounded looper step), so it must be
  # tightly bounded and fail fast. @grpc_timeout is the per-call gRPC deadline;
  # @timeout is a slightly larger Wormhole backstop covering connect hangs.
  @grpc_timeout 1_000
  @timeout 1_500

  alias InternalApi.Feature, as: API
  alias API.FeatureService.Stub
  require Logger

  @doc """
  Calls the Feature gRPC API to list the features enabled for an organization.
  """
  @spec list_organization_features(String.t()) ::
          {:ok, [InternalApi.Feature.OrganizationFeature.t()]}
          | {:error, :timeout}
          | {:error, any()}
  def list_organization_features(organization_id) do
    result =
      Wormhole.capture(__MODULE__, :do_list_organization_features, [organization_id],
        stacktrace: true,
        timeout: @timeout
      )

    case result do
      {:ok, features} ->
        {:ok, features}

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
  def do_list_organization_features(organization_id) do
    Watchman.benchmark("#{@watchman_prefix_key}.list_organization_features.duration", fn ->
      request = API.ListOrganizationFeaturesRequest.new(org_id: organization_id)

      case send_request(request) do
        {:ok, response} ->
          Watchman.increment("#{@watchman_prefix_key}.list_organization_features.success")
          response.organization_features

        {:error, reason} ->
          Watchman.increment("#{@watchman_prefix_key}.list_organization_features.failure")
          raise reason
      end
    end)
  end

  defp send_request(request) do
    url =
      System.get_env(@url_env_var) || raise "environment variable #{@url_env_var} was not found"

    with {:ok, channel} <- GRPC.Stub.connect(url) do
      Watchman.increment("#{@watchman_prefix_key}.list_organization_features.connect")

      try do
        Stub.list_organization_features(channel, request, timeout: @grpc_timeout)
      after
        GRPC.Stub.disconnect(channel)
      end
    end
  end

  #
  # Logging functions
  #

  defp log_timeout(organization_id, _timeout) do
    metadata = log_metadata(organization_id: organization_id)
    Logger.error("Ppl.FeatureClient.list_organization_features/1: TIMEOUT #{metadata}")
  end

  defp log_shutdown(organization_id, reason) do
    metadata = log_metadata(organization_id: organization_id, reason: reason)
    Logger.error("Ppl.FeatureClient.list_organization_features/1: SHUTDOWN #{metadata}")
  end

  defp log_metadata(metadata) do
    formatter = &"#{elem(&1, 0)}=#{inspect(elem(&1, 1))}"
    metadata |> Enum.map_join(" ", formatter)
  end
end
