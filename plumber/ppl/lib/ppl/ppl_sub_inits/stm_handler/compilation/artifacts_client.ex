defmodule Ppl.PplSubInits.STMHandler.Compilation.AtifactsClient do
  @moduledoc """
  Pulls artifacts from artifact service
  """

  alias InternalApi.Artifacthub.GetSignedURLRequest
  alias InternalApi.Artifacthub.ArtifactService
  alias Util.{Metrics, Proto}

  require Logger

  defp artifacts_url(), do: System.get_env("INTERNAL_API_URL_ARTIFACTHUB")
  @opts [{:timeout, 5_000_000}]

  @doc """
  Returns string content of the file on the given path in workflow level artifact
  """
  def acquire_file(artifact_id, wf_id, path) do
    with {:ok, %{url: url}} <- get_url(artifact_id, wf_id, path),
         do: get_file(url)
  end

  defp get_file(url) do
    with {:ok, response} <- HTTPoison.get(url),
         %{status_code: 200, body: content} <- response
    do
      {:ok, content}
    else
      %{status_code: 404, body: error} -> {:error, {:not_found, error}}
      error = {:error, _e} -> error
      error -> {:error, error}
    end
  end

  @doc """
  Entrypoint for get_signed_url call from ppl application.
  """
  def get_url(artifact_id, wf_id, path) do
    result =  Wormhole.capture(__MODULE__, :get_signed_url, [artifact_id, wf_id, path],
                                            stacktrace: true, timeout: 5_000)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def get_signed_url(artifact_id, wf_id, path) do
    Metrics.benchmark("AtifactsClient.get_signed_url", fn ->
      path = "artifacts/workflows/#{wf_id}/#{path}"
      request =
        %{artifact_id: artifact_id, path: path}
        |> Proto.deep_new!(GetSignedURLRequest)

      {:ok, channel} = GRPC.Stub.connect(artifacts_url())

      Logger.info("Getting signed url with request: #{inspect(request)}")


      response = channel
      |> ArtifactService.Stub.get_signed_url(request, @opts)

      Logger.info("Response: #{inspect(response)}")

      response
      |> response_to_map()
    end)
  end

  defp response_to_map({:ok, response}), do: Proto.to_map(response)
  defp response_to_map(error = {:error, _msg}), do: error
  defp response_to_map(error), do: {:error, error}
end
