defmodule InternalClients.RepoProxy do
  @moduledoc """
  Module is used for communication with RepoProxy service over gRPC.
  """

  alias PublicAPI.Util.{Metrics, ToTuple}
  alias InternalApi.RepoProxy.{CreateRequest, RepoProxyService}
  alias LogTee, as: LT

  defp url(), do: System.get_env("REPO_PROXY_URL")

  @wormhole_timeout Application.compile_env(:public_api, :grpc_timeout, [])

  def create(params) do
    Metrics.benchmark(__MODULE__, ["create"], fn ->
      params
      |> form_request()
      |> grpc_call()
    end)
  end

  defp form_request(params) do
    %CreateRequest{
      request_token: UUID.uuid4(),
      project_id: params |> Map.get(:project_id, ""),
      requester_id: params |> Map.get(:requester_id, ""),
      definition_file: params |> Map.get(:pipeline_file, ""),
      git: %{
        reference: params |> Map.get(:reference, "") |> ref(),
        commit_sha: params |> Map.get(:commit_sha, "")
      },
      triggered_by: :API
    }
  catch
    error -> error
  end

  defp ref(""), do: ""
  defp ref(value = "refs/" <> _rest), do: value
  defp ref(branch_name), do: "refs/heads/" <> branch_name

  defp grpc_call(request) do
    result =
      Wormhole.capture(__MODULE__, :call_repo_proxy, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout,
        ok_tuple: true
      )

    case result do
      {:ok, result} ->
        {:ok, %{wf_id: result.workflow_id, ppl_id: result.pipeline_id, hook_id: result.hook_id}}

      # Not_found, Invalid_argument and Aborted errors
      {:error, {:error, %GRPC.RPCError{message: msg, status: status}}}
      when status in [3, :invalid_argument, 5, :not_found, 10, :aborted] ->
        ToTuple.user_error(%{message: msg})

      {:error, reason} ->
        reason |> LT.error("RepoProxy service responded to 'create' with:")
        ToTuple.internal_error(%{message: "Internal error"})
    end
  end

  def call_repo_proxy(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect()

    RepoProxyService.Stub.create(channel, request, timeout: @wormhole_timeout)
  end
end
