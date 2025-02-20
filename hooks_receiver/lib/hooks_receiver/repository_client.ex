defmodule HooksReceiver.RepositoryClient do
  @moduledoc """
  Calls Repository API
  """

  alias Util.{Metrics, ToTuple}
  alias InternalApi.Repository.{RepositoryService, DescribeRequest}

  defp url, do: Application.get_env(:hooks_receiver, :repository_api_grpc)
  @opts [{:timeout, 2_500_000}]

  @doc """
  Entrypoint for describe repository call from hook_receiver application.
  """
  def describe(repository_id) do
    result =
      Wormhole.capture(__MODULE__, :describe_repository, [repository_id],
        stacktrace: true,
        timeout: 3_000
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_repository(repository_id) do
    Metrics.benchmark("HooksReceiver.RepositoryClient.describe", fn ->
      request = %DescribeRequest{repository_id: repository_id}
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> RepositoryService.Stub.describe(request, @opts)
      |> process_response()
    end)
  end

  defp process_response({:ok, map}), do: map |> Map.get(:repository) |> ToTuple.ok()
end
