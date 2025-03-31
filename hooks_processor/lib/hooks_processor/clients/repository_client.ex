defmodule HooksProcessor.Clients.RepositoryClient do
  @moduledoc """
  Module is used for communication with Repository service over gRPC.
  """

  alias InternalApi.Repository.{
    RepositoryService,
    DescribeRevisionRequest,
    VerifyWebhookSignatureRequest,
    RegenerateWebhookRequest,
    CheckWebhookRequest
  }

  alias Util.{Metrics, ToTuple}
  alias LogTee, as: LT

  defp url, do: Application.get_env(:hooks_processor, :repository_grpc_url)

  @wormhole_timeout 6_000
  @grpc_timeout 5_000

  # RegenerateWebhook

  def regenerate_webhook(repository_id) do
    "repository_id: #{repository_id}"
    |> LT.info("Calling Repository API to regenerate webhook")

    Metrics.benchmark("HooksProcessor.RepositoryClient", ["regenerate_webhook"], fn ->
      %RegenerateWebhookRequest{
        repository_id: repository_id
      }
      |> do_regenerate_webhook()
    end)
  end

  defp do_regenerate_webhook(request) do
    result =
      Wormhole.capture(__MODULE__, :regenerate_webhook_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def regenerate_webhook_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> RepositoryService.Stub.regenerate_webhook(request, timeout: @grpc_timeout)
    |> process_regenerate_webhook_status()
  end

  defp process_regenerate_webhook_status({:ok, regenerate_response}) do
    regenerate_response
    |> Map.get(:webhook)
    |> ToTuple.ok()
  end

  defp process_regenerate_webhook_status(error = {:error, _msg}), do: error
  defp process_regenerate_webhook_status(error), do: {:error, error}

  # CheckWebhook
  def check_webhook(repository_id) do
    "repository_id: #{repository_id}"
    |> LT.info("Calling Repository API to check webhook")

    Metrics.benchmark("HooksProcessor.RepositoryClient", ["check_webhook"], fn ->
      %CheckWebhookRequest{
        repository_id: repository_id
      }
      |> do_check_webhook()
    end)
  end

  defp do_check_webhook(request) do
    result =
      Wormhole.capture(__MODULE__, :check_webhook_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def check_webhook_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> RepositoryService.Stub.check_webhook(request, timeout: @grpc_timeout)
    |> process_check_webhook_status()
  end

  defp process_check_webhook_status({:ok, check_response}) do
    check_response
    |> Map.get(:webhook)
    |> ToTuple.ok()
  end

  defp process_check_webhook_status(error = {:error, _msg}), do: error
  defp process_check_webhook_status(error), do: {:error, error}

  # DescribeRevision

  def describe_revision(repository_id, reference, commit_sha) do
    "repository_id: #{repository_id} and reference: #{inspect(reference)} and commit_sha: #{inspect(commit_sha)}"
    |> LT.info("Calling Repository API to describe revision")

    Metrics.benchmark("HooksProcessor.RepositoryClient", ["describe_revision"], fn ->
      %DescribeRevisionRequest{
        repository_id: repository_id,
        revision: %{reference: reference, commit_sha: commit_sha}
      }
      |> do_describe_revision()
    end)
  end

  defp do_describe_revision(request) do
    result =
      Wormhole.capture(__MODULE__, :describe_revision_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_revision_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> RepositoryService.Stub.describe_revision(request, timeout: @grpc_timeout)
    |> process_describe_revision_status()
  end

  defp process_describe_revision_status({:ok, describe_response}) do
    describe_response
    |> Map.get(:commit)
    |> ToTuple.ok()
  end

  defp process_describe_revision_status(error = {:error, _msg}), do: error
  defp process_describe_revision_status(error), do: {:error, error}

  def verify_webhook_signature(organization_id, repository_id, payload, signature) do
    "organization_id: #{organization_id} and repository_id: #{repository_id} and signature: #{signature}"
    |> LT.info("Calling Repository API to verify webhook signature")

    Metrics.benchmark("HooksProcessor.RepositoryClient", ["verify_webhook_signature"], fn ->
      %VerifyWebhookSignatureRequest{
        organization_id: organization_id,
        repository_id: repository_id,
        payload: payload,
        signature: signature
      }
      |> do_verify_webhook_signature()
    end)
  end

  defp do_verify_webhook_signature(request) do
    result =
      Wormhole.capture(__MODULE__, :verify_webhook_signature_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def verify_webhook_signature_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> RepositoryService.Stub.verify_webhook_signature(request, timeout: @grpc_timeout)
    |> process_verify_webhook_signature_status()
  end

  defp process_verify_webhook_signature_status({:ok, verify_response}) do
    verify_response
    |> Map.get(:valid)
    |> ToTuple.ok()
  end

  defp process_verify_webhook_signature_status(error = {:error, _msg}), do: error
  defp process_verify_webhook_signature_status(error), do: {:error, error}
end
