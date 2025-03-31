defmodule HooksReceiver.RepositoryClient do
  @moduledoc """
  Calls Repository API
  """

  alias Util.{Metrics, ToTuple}

  alias InternalApi.Repository.{
    RepositoryService,
    DescribeRequest,
    CheckWebhookRequest,
    RegenerateWebhookRequest
  }

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
      |> case do
        {:ok, response} ->
          response
          |> Map.get(:repository)
          |> ToTuple.ok()

        {:error, error} ->
          error
      end
    end)
  end

  def check_webhook(repository_id) do
    Metrics.benchmark("HooksReceiver.RepositoryClient.check_webhook", fn ->
      request = %CheckWebhookRequest{repository_id: repository_id}
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> RepositoryService.Stub.check_webhook(request, @opts)
      |> case do
        {:ok, response} ->
          response
          |> Map.get(:webhook)
          |> ToTuple.ok()

        {:error, error} ->
          error
      end
    end)
  end

  def regenerate_webhook(repository_id) do
    Metrics.benchmark("HooksReceiver.RepositoryClient.regenerate_webhook", fn ->
      request = %RegenerateWebhookRequest{repository_id: repository_id}
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> RepositoryService.Stub.regenerate_webhook(request, @opts)
      |> case do
        {:ok, response} ->
          response
          |> Map.get(:webhook)
          |> ToTuple.ok()

        {:error, error} ->
          error
      end
    end)
  end
end
