defmodule PipelinesAPI.RepoProxyClient do
  @moduledoc """
  Module is used for communication with RepoProxy service over gRPC.
  """

  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias InternalApi.RepoProxy.{CreateRequest, RepoProxyService}
  alias Util.Proto
  alias LogTee, as: LT

  defp url(), do: System.get_env("REPO_PROXY_URL")

  @wormhole_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])

  def create(params) do
    Metrics.benchmark(__MODULE__, ["create"], fn ->
      params
      |> form_request()
      |> grpc_call()
    end)
  end

  defp form_request(params) do
    %{
      request_token: UUID.uuid4(),
      project_id: params |> Map.get("project_id", ""),
      requester_id: params |> Map.get("requester_id", ""),
      definition_file: params |> Map.get("pipeline_file", ""),
      git: %{
        reference: params |> Map.get("reference", "") |> ref(),
        commit_sha: params |> Map.get("commit_sha", "")
      },
      triggered_by: :API
    }
    |> Proto.deep_new(CreateRequest)
  catch
    error -> error
  end

  defp ref(""), do: ""
  defp ref(value = "refs/" <> _rest), do: value
  defp ref(branch_name), do: "refs/heads/" <> branch_name

  defp grpc_call({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :call_repo_proxy, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout,
        ok_tuple: true
      )

    case result do
      {:ok, result} ->
        Proto.to_map(result)

      # Not_found, Invalid_argument and Aborted errors
      {:error, {:error, %GRPC.RPCError{message: msg, status: status}}}
      when status in [3, 5, 10] ->
        ToTuple.user_error(msg)

      {:error, reason} ->
        reason |> LT.error("RepoProxy service responded to 'create' with:")
        ToTuple.internal_error("Internal error")
    end
  end

  def call_repo_proxy(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect()

    RepoProxyService.Stub.create(channel, request, timeout: @wormhole_timeout)
  end
end
