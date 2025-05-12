defmodule HooksProcessor.Clients.RepositoryClient do
  @moduledoc """
  Module is used for communication with Repository service over gRPC.
  """

  alias InternalApi.Repository.{RepositoryService, DescribeRevisionRequest, VerifyWebhookSignatureRequest}

  alias Util.{Metrics, ToTuple}
  alias LogTee, as: LT

  defp url, do: Application.get_env(:hooks_processor, :repository_grpc_url)

  @wormhole_timeout 6_000
  @grpc_timeout 5_000

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
