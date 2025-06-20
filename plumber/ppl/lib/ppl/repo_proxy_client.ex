defmodule Ppl.RepoProxyClient do
  @moduledoc """
  Calls RepoProxy API
  """

  alias LogTee, as: LT
  alias Util.{Metrics, Proto, ToTuple}

  alias InternalApi.RepoProxy.{
    RepoProxyService,
    DescribeRequest,
    CreateBlankRequest,
    Hook.Type
  }

  alias InternalApi.PlumberWF.TriggeredBy

  defp old_url(), do: System.get_env("INTERNAL_API_URL_REPO_PROXY")
  defp new_url(), do: System.get_env("REPO_PROXY_NEW_GRPC_URL")
  @opts [{:timeout, 2_500_000}]

  @doc """
  Entrypoint for describe hook call from ppl application.
  """
  def describe(hook_id) do
    result =  Wormhole.capture(__MODULE__, :describe_hook, [hook_id], stacktrace: true, timeout: 3_000)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_hook(hook_id) do
    Metrics.benchmark("Ppl.RepoProxyClient.describe", fn ->
      request = DescribeRequest.new(hook_id: hook_id)
      {:ok, channel} = GRPC.Stub.connect(old_url())

      channel
      |> RepoProxyService.Stub.describe(request, @opts)
      |> response_to_map()
      |> process_status()
    end)
  end

  def create_blank(ppl_req) do
    result =
      Wormhole.capture(__MODULE__, :do_create_blank, [ppl_req],
        stacktrace: true,
        timeout: 5_000
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def do_create_blank(ppl_req) do
    Metrics.benchmark("Ppl.RepoProxyClient.create_blank", fn ->
      request =
        CreateBlankRequest.new(
          pipeline_id: ppl_req.id,
          wf_id: ppl_req.wf_id,
          request_token: ppl_req.request_token,
          requester_id: ppl_req.request_args |> Map.get("requester_id", ""),
          project_id: ppl_req.request_args |> Map.get("project_id", ""),
          definition_file: ppl_req.request_args |> Map.get("file_name", ""),
          triggered_by: triggered_by_from_ppl_req(ppl_req),
          git:
            CreateBlankRequest.Git.new(
              reference: git_reference_from_ppl_req(ppl_req),
              commit_sha: ppl_req.request_args |> Map.get("commit_sha", "")
            )
        )

      {:ok, channel} =
        if ppl_req.request_args |> Map.get("service", "") == "git_hub" do
          GRPC.Stub.connect(old_url())
        else
          GRPC.Stub.connect(new_url())
        end

      channel
      |> RepoProxyService.Stub.create_blank(request, @opts)
      |> response_to_map()
    end)
  end

  defp triggered_by_from_ppl_req(ppl_req) do
    ppl_req.request_args
    |> Map.get("triggered_by")
    |> String.upcase()
    |> case do
      "HOOK" -> TriggeredBy.value(:HOOK)
      "SCHEDULE" -> TriggeredBy.value(:SCHEDULE)
      "API" -> TriggeredBy.value(:API)
      "MANUAL_RUN" -> TriggeredBy.value(:MANUAL_RUN)
      value -> raise "Invalid triggered_by value: #{value}}"
    end
  end

  defp git_reference_from_ppl_req(ppl_req) do
    git_ref = ppl_req.request_args |> Map.get("git_reference", "")

    if git_ref == "" do
      branch_name = ppl_req.request_args |> Map.get("branch_name", "")
      "refs/heads/#{branch_name}"
    else
      git_ref
    end
  end

  defp process_status({:ok, map}) do
    case map |> Map.get(:status, %{}) |> Map.get(:code) do
      :OK ->
         map |> Map.get(:hook) |> ToTuple.ok()

      :BAD_PARAM ->
         map |> Map.get(:status, %{}) |> Map.get(:message) |> ToTuple.error()

      _ -> log_invalid_response(map)
    end
  end
  defp process_status(error = {:error, _msg}), do: error
  defp process_status(error), do: {:error, error}

  # Utility

  defp response_to_map({:ok, response}) do
    with tf_map     <- %{Type => {__MODULE__, :atom_to_lower_string}},
    do: response |> Proto.to_map(transformations: tf_map)
  end
  defp response_to_map(error = {:error, _msg}), do: error
  defp response_to_map(error), do: {:error, error}

  def atom_to_lower_string(_name, value) do
    value |> Type.key() |> Atom.to_string() |> String.downcase()
  end

  defp log_invalid_response(response) do
    response
    |> LT.error("Repo Proxy responded to Descr with :ok and invalid data:")
    |> ToTuple.error()
  end
end
