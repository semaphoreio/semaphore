defmodule HooksReceiver.OrganizationClient do
  @moduledoc """
  Calls Organization API
  """

  require Logger

  alias Util.{Metrics, ToTuple}
  alias InternalApi.Organization.{OrganizationService, DescribeRequest}

  defp url, do: System.get_env("INTERNAL_API_URL_ORGANIZATION")
  @opts [{:timeout, 2_500_000}]

  @doc """
  Entrypoint for describe organization call from hook_receiver application.
  """
  def describe(org_id) do
    result =
      Wormhole.capture(__MODULE__, :describe_organization, [org_id],
        stacktrace: true,
        timeout: 3_000
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_organization(org_id) do
    Metrics.benchmark("HooksReceiver.OrganizationClient.describe", fn ->
      request = %DescribeRequest{org_id: org_id}
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> OrganizationService.Stub.describe(request, @opts)
      |> response_to_map()
      |> process_status()
    end)
  end

  defp process_status({:ok, map}) do
    case map |> Map.get(:status, %{}) |> Map.get(:code) do
      :OK ->
        map |> Map.get(:organization) |> ToTuple.ok()

      :BAD_PARAM ->
        map |> Map.get(:status, %{}) |> Map.get(:message) |> ToTuple.error()

      _ ->
        log_invalid_response(map)
    end
  end

  defp process_status(error = {:error, _msg}), do: error
  defp process_status(error), do: {:error, error}

  # Utility

  defp response_to_map({:ok, response}), do: {:ok, response}

  defp response_to_map(error = {:error, _msg}), do: error
  defp response_to_map(error), do: {:error, error}

  defp log_invalid_response(response) do
    response
    |> tap(fn response ->
      Logger.error(
        "OrganizationAPI responded to Describe with :ok and invalid data: #{inspect(response)}"
      )
    end)
    |> ToTuple.error()
  end
end
