defmodule HooksProcessor.Clients.AdminClient do
  require Logger

  alias InternalApi.Plumber.{Admin, TerminateAllRequest}

  @spec terminate_all_pipelines(project_id :: String.t(), branch_name :: String.t(), reason :: atom()) :: any()
  def terminate_all_pipelines(project_id, branch_name, reason) do
    request = %TerminateAllRequest{
      project_id: project_id,
      branch_name: branch_name,
      reason: reason
    }

    Logger.info(
      "Calling Admin API to terminate all pipelines for project_id: #{project_id} and branch_name: #{branch_name}"
    )

    channel()
    |> Admin.Stub.terminate_all(request)
    |> process_terminate_all_status()
  end

  defp process_terminate_all_status({:ok, response}) do
    case response |> Map.get(:response_status, %{}) |> Map.get(:code) do
      :OK ->
        :ok

      code when code in [:BAD_PARAM, :LIMIT_EXCEEDED, :REFUSED] ->
        {:error, response |> Map.get(:response_status, %{}) |> Map.get(:message)}

      _ ->
        {:error, :unknown}
    end
  end

  defp process_terminate_all_status(error = {:error, _msg}) do
    Logger.error("Error while terminating all pipelines: #{inspect(error)}")
    {:error, error}
  end

  defp url, do: Application.get_env(:hooks_processor, :plumber_grpc_url)

  defp channel do
    {:ok, channel} = GRPC.Stub.connect(url())
    channel
  end
end
