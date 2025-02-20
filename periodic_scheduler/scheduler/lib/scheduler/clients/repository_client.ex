defmodule Scheduler.Clients.RepositoryClient do
  @moduledoc """
  Calls Repository API (repositoryhub)
  """

  alias InternalApi.Repository, as: API

  def describe_revision(repository_id, revision_args) do
    result =
      Wormhole.capture(__MODULE__, :do_describe_revision, [repository_id, revision_args],
        stacktrace: true,
        timeout: 10_000
      )

    case result do
      {:ok, result} ->
        result

      {:error, reason} ->
        LogTee.error(reason, "Projecthub service responded to 'describe' with:")
        {:error, reason}
    end
  end

  def do_describe_revision(repository_id, revision_args) do
    grpc_call(
      API.DescribeRevisionRequest.new(
        repository_id: repository_id,
        revision: API.Revision.new(revision_args)
      )
    )
  end

  defp grpc_call(request) do
    stub_func = grpc_for_request(request)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint()),
         {:ok, response} <- grpc_send(channel, stub_func, request) do
      parse_response(response)
    else
      {:error, _reason} = error -> error
    end
  end

  defp endpoint, do: Application.get_env(:scheduler, :repositoryhub_grpc_endpoint)

  defp grpc_send(channel, func, request),
    do: func.(channel, request),
    after: GRPC.Stub.disconnect(channel)

  defp grpc_for_request(%API.DescribeRevisionRequest{}),
    do: &API.RepositoryService.Stub.describe_revision/2

  defp parse_response(%API.DescribeRevisionResponse{commit: commit}),
    do: {:ok, commit}
end
