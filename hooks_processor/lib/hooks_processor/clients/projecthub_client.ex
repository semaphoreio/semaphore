defmodule HooksProcessor.Clients.ProjectHubClient do
  @moduledoc """
  Module is used for communication with ProjectHub service over gRPC.
  """

  alias InternalApi.Projecthub.{ProjectService, DescribeRequest}
  alias Util.{Metrics, ToTuple}
  alias LogTee, as: LT

  defp url, do: Application.get_env(:hooks_processor, :projecthub_grpc_url)

  @wormhole_timeout 6_000
  @grpc_timeout 5_000

  def describe_project(project_id) do
    result =
      Wormhole.capture(__MODULE__, :describe, [project_id],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe(project_id) do
    Metrics.benchmark("HooksProcessor.ProjectHubClient.describe", fn ->
      request = %DescribeRequest{
        id: project_id,
        metadata: %{api_version: "", kind: "", req_id: "", org_id: "", user_id: ""}
      }

      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> ProjectService.Stub.describe(request, timeout: @grpc_timeout)
      |> process_status()
    end)
  end

  defp process_status({:ok, map}) do
    status = map |> Map.get(:metadata, %{}) |> Map.get(:status, %{})

    case status |> Map.get(:code) do
      :OK ->
        extract_project(map)
        |> Map.put(:repository, extract_repository(map))
        |> ToTuple.ok()

      :NOT_FOUND ->
        status |> Map.get(:message) |> ToTuple.error()

      :FAILED_PRECONDITION ->
        status |> Map.get(:message) |> ToTuple.error()

      _ ->
        log_invalid_response(map)
    end
  end

  defp process_status(error = {:error, _msg}), do: error
  defp process_status(error), do: {:error, error}

  # Utility

  defp log_invalid_response(response) do
    response
    |> LT.error("ProjectHub Service responded to Describe with :ok and invalid data:")
    |> ToTuple.error()
  end

  defp extract_repository(data) do
    data
    |> Map.get(:project, %{})
    |> Map.get(:spec, %{})
    |> Map.get(:repository)
  end

  defp extract_project(data) do
    data
    |> Map.get(:project, %{})
    |> Map.get(:metadata, %{})
    |> Map.take([:id, :org_id])
  end
end
