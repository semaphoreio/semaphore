defmodule PipelinesAPI.WorkflowClient.WFRequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with Workflow service.
  """

  alias Util.Proto
  alias InternalApi.PlumberWF.ScheduleRequest
  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.PlumberWF.TerminateRequest
  alias InternalApi.PlumberWF.RescheduleRequest
  alias InternalApi.PlumberWF.DescribeRequest

  def form_schedule_request(params) when is_map(params) do
    %{
      service: service_type(params["repository"].integration_type),
      label: params |> Map.get("reference", "") |> label(),
      repo: %{
        branch_name: params |> Map.get("reference", "") |> branch_name(),
        commit_sha: params |> Map.get("commit_sha", "")
      },
      request_token: UUID.uuid4(),
      project_id: params["project_id"],
      requester_id: Map.get(params, "requester_id", ""),
      definition_file: Map.get(params, "pipeline_file", ".semaphore/semaphore.yml"),
      organization_id: Map.get(params, "organization_id", ""),
      git_reference: params |> Map.get("reference", "") |> ref(),
      start_in_conceived_state: true,
      triggered_by: :API,
      env_vars: parameter_values_to_env_vars(params["parameters"])
    }
    |> Proto.deep_new(ScheduleRequest)
  end

  def form_schedule_request(_), do: ToTuple.internal_error("Internal error")

  defp service_type(:GITHUB_OAUTH_TOKEN), do: :GIT_HUB
  defp service_type(:GITHUB_APP), do: :GIT_HUB
  defp service_type(:BITBUCKET), do: :BITBUCKET
  defp service_type(:GITLAB), do: :GITLAB
  defp service_type(:GIT), do: :GIT

  defp parameter_values_to_env_vars(nil), do: []

  defp parameter_values_to_env_vars(parameter_values) do
    Enum.into(parameter_values, [], &parameter_value_to_env_var/1)
  end

  defp parameter_value_to_env_var({name, value}) do
    %{name: name, value: if(is_nil(value), do: "", else: value)}
  end

  defp ref(""), do: ""
  defp ref(value = "refs/" <> _rest), do: value
  defp ref(branch_name), do: "refs/heads/" <> branch_name

  defp branch_name(""), do: ""
  defp branch_name(tag = "refs/tags/" <> _rest), do: tag
  defp branch_name("refs/pull/" <> number), do: "pull-request-" <> number
  defp branch_name("refs/heads/" <> branch_name), do: branch_name
  defp branch_name(name), do: name

  defp label(""), do: ""
  defp label("refs/tags/" <> tag), do: tag
  defp label("refs/pull/" <> number), do: number
  defp label("refs/heads/" <> branch_name), do: branch_name
  defp label(name), do: name

  # Terminate

  def form_terminate_request(wf_id, requester_id) when is_binary(wf_id) do
    %{wf_id: wf_id, requester_id: requester_id} |> TerminateRequest.new() |> ToTuple.ok()
  end

  def form_terminate_request(_error),
    do: "Parameter wf_id must be a string." |> ToTuple.user_error()

  # Reschedule

  def form_reschedule_request(wf_id, requester_id, request_token) when is_binary(wf_id) do
    with {:ok, req_token} <- check_request_token(request_token),
         do:
           %{wf_id: wf_id, requester_id: requester_id, request_token: req_token}
           |> RescheduleRequest.new()
           |> ToTuple.ok()
  end

  def form_partial_rebuild_request(_), do: ToTuple.internal_error("Internal error")

  defp check_request_token(req_token) do
    case req_token do
      req_token when is_binary(req_token) and req_token != "" -> req_token |> ToTuple.ok()
      _ -> "Missing required post parameter request_token." |> ToTuple.user_error()
    end
  end

  # Describe

  def form_describe_request(wf_id) when is_binary(wf_id) do
    %{wf_id: wf_id}
    |> DescribeRequest.new()
    |> ToTuple.ok()
  end
end
