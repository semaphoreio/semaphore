defmodule Scheduler.Clients.ProjecthubClient do
  @moduledoc """
  Calls Project API (projecthub)
  """

  alias InternalApi.Projecthub, as: API

  def describe(project_id) do
    result =
      Wormhole.capture(__MODULE__, :do_describe, [project_id],
        stacktrace: true,
        timeout: 5_000,
        ok_tuple: true
      )

    case result do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        LogTee.error(reason, "Projecthub service responded to 'describe' with:")
        {:error, reason}
    end
  end

  def do_describe(project_id) do
    grpc_call(
      API.DescribeRequest.new(
        metadata: API.RequestMeta.new(),
        id: project_id
      )
    )
  end

  defp grpc_call(request) do
    stub_func = grpc_for_request(request)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint()),
         {:ok, response} <- grpc_send(channel, stub_func, request) do
      parse_response(response.metadata.status, response)
    else
      {:error, _reason} = error -> error
    end
  end

  defp endpoint, do: Application.get_env(:scheduler, :projecthub_api_grpc_endpoint)

  defp grpc_send(channel, func, request),
    do: func.(channel, request),
    after: GRPC.Stub.disconnect(channel)

  defp grpc_for_request(%API.DescribeRequest{}),
    do: &API.ProjectService.Stub.describe/2

  defp parse_response(%{code: :OK}, response = %API.DescribeResponse{}) do
    {:ok, response.project}
  end

  defp parse_response(%{code: code, message: message}, _response) do
    %{code: code, message: message}
  end
end
