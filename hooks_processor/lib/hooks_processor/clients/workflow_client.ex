defmodule HooksProcessor.Clients.WorkflowClient do
  @moduledoc """
  Module is used for communication with Plumber Workflows service over gRPC.
  """

  alias Util.{Metrics, ToTuple}
  alias InternalApi.PlumberWF.{WorkflowService, ScheduleRequest}
  alias LogTee, as: LT

  defp url, do: Application.get_env(:hooks_processor, :plumber_grpc_url)

  @wormhole_timeout 16_000
  @grpc_timeout 15_000

  def schedule_workflow(webhook, parsed_data, triggered_by \\ :HOOK) do
    parsed_data.yml_file
    |> LT.info("Hook #{webhook.id} - scheduling workflow on Plumber with definition from")

    %ScheduleRequest{
      requester_id: parsed_data.requester_id,
      organization_id: webhook.organization_id,
      project_id: webhook.project_id,
      branch_id: parsed_data.branch_id,
      hook_id: webhook.id,
      request_token: webhook.id,
      triggered_by: triggered_by,
      service: provider_to_service_type(parsed_data.provider),
      definition_file: parsed_data.yml_file,
      label: label(parsed_data.branch_name),
      repo: %{
        owner: parsed_data.owner,
        repo_name: parsed_data.repo_name,
        branch_name: parsed_data.branch_name,
        commit_sha: parsed_data.commit_sha,
        repository_id: webhook.repository_id
      }
    }
    |> schedule()
  end

  defp label("refs/tags/" <> rest), do: rest
  defp label("pull-request-" <> rest), do: rest
  defp label(branch_name), do: branch_name

  defp schedule(params) do
    Metrics.benchmark("HooksProcessor.WorkflowClient", ["schedule"], fn ->
      params
      |> schedule_grpc()
      |> process_schedule_response()
    end)
  end

  def provider_to_service_type("github"), do: :GIT_HUB
  def provider_to_service_type("bitbucket"), do: :BITBUCKET
  def provider_to_service_type("gitlab"), do: :GITLAB
  def provider_to_service_type("git"), do: :GIT
  def provider_to_service_type(_), do: :GIT_HUB

  defp schedule_grpc(schedule_request) do
    result =
      Wormhole.capture(__MODULE__, :schedule_grpc_, [schedule_request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def schedule_grpc_(schedule_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> WorkflowService.Stub.schedule(schedule_request, timeout: @grpc_timeout)
    |> ok?("schedule")
  end

  def process_schedule_response({:ok, schedule_response}) do
    with true <- is_map(schedule_response),
         {:ok, status} <- Map.fetch(schedule_response, :status),
         {:code, :OK} <- {:code, Map.get(status, :code)} do
      {:ok, schedule_response}
    else
      {:code, _} -> when_status_code_not_ok(schedule_response)
      _ -> log_invalid_response(schedule_response, "schedule")
    end
  end

  def process_schedule_response(error), do: error

  defp when_status_code_not_ok(schedule_response) do
    schedule_response
    |> Map.get(:status)
    |> ToTuple.error()
  end

  # Utility

  defp ok?(response = {:ok, _rsp}, _method), do: response

  defp ok?({:error, error}, rpc_method) do
    error |> LT.warn("WorkflowPB service responded to #{rpc_method} request with: ")
    {:error, {:grpc_error, error}}
  end

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("WorkflowPB service responded to #{rpc_method} with :ok and invalid data:")

    {:error, {:grpc_error, response}}
  end
end
